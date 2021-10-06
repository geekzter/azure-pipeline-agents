data cloudinit_config user_data {
  gzip                         = false
  base64_encode                = false

  dynamic "part" {
    for_each = range(var.prepare_host ? 1 : 0)
    content {
      content                  = templatefile("${path.root}/../cloudinit/cloud-config-userdata.yaml",
      {
        outbound_ip            = var.outbound_ip_address
        subnet_id              = var.subnet_id
        virtual_network_id     = local.virtual_network_id
      })
      content_type             = "text/cloud-config"
    }
  }

  part {
    content                    = templatefile("${path.module}/cloud-config-agent.yaml",
    {
      agent_name               = var.pipeline_agent_name
      agent_pool               = var.pipeline_agent_pool
      install_agent_script_b64 = filebase64("${path.root}/../scripts/agent/install_agent.sh")
      org                      = var.devops_org
      pat                      = var.devops_pat
      user                     = var.user_name
    })
    content_type               = "text/cloud-config"
    merge_type                 = "list(append)+dict(recurse_array)+str()"
  }

}

resource azurerm_public_ip linux_pip {
  name                         = "${var.name}-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags
}

resource azurerm_network_interface linux_nic {
  name                         = "${var.name}-nic"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id       = azurerm_public_ip.linux_pip.id
  }
  enable_accelerated_networking = var.vm_accelerated_networking

  tags                         = var.tags
}

resource azurerm_network_security_rule admin_ssh {
  name                         = "AdminSSH${count.index+1}"
  priority                     = count.index+201
  direction                    = "Inbound"
  access                       = var.public_access_enabled ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefix        = var.admin_cidr_ranges[count.index]
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name

  count                        = length(var.admin_cidr_ranges)
}

resource azurerm_network_interface_security_group_association linux_nic_nsg {
  network_interface_id         = azurerm_network_interface.linux_nic.id
  network_security_group_id    = azurerm_network_security_group.nsg.id
}

resource azurerm_linux_virtual_machine linux_agent {
  name                         = var.name
  computer_name                = var.computer_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  size                         = var.vm_size
  admin_username               = var.user_name
  admin_password               = var.user_password
  custom_data                  = base64encode(data.cloudinit_config.user_data.rendered)
  disable_password_authentication = false
  network_interface_ids        = [azurerm_network_interface.linux_nic.id]

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  boot_diagnostics {
    storage_account_uri        = "${data.azurerm_storage_account.diagnostics.primary_blob_endpoint}${var.diagnostics_storage_sas}"
  }

  os_disk {
    name                       = "${var.name}-osdisk"
    caching                    = "ReadWrite"
    storage_account_type       = var.storage_type
  }

  source_image_reference {
    publisher                  = var.os_publisher
    offer                      = var.os_offer
    sku                        = var.os_sku
    version                    = "latest"
  }

  lifecycle {
    ignore_changes             = [
      custom_data
    ]
  }  

  tags                         = var.tags
  depends_on                   = [azurerm_network_interface_security_group_association.linux_nic_nsg]
}

resource azurerm_virtual_machine_extension cloud_config_status {
  name                         = "CloudConfigStatusScript"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  settings                     = jsonencode({
    "commandToExecute"         = "/usr/bin/cloud-init status --long --wait ; systemctl status cloud-final.service --full --no-pager --wait"
  })

  tags                         = var.tags
}
resource azurerm_virtual_machine_extension linux_log_analytics {
  name                         = "OmsAgentForLinux"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "OmsAgentForLinux"
  type_handler_version         = "1.7"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  tags                         = var.tags

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
  depends_on                   = [azurerm_virtual_machine_extension.cloud_config_status]
}
resource azurerm_virtual_machine_extension linux_dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent.id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentLinux"
  type_handler_version         = "9.5"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  tags                         = var.tags

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
  depends_on                   = [azurerm_virtual_machine_extension.cloud_config_status]
}
resource azurerm_virtual_machine_extension linux_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentLinux"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  tags                         = var.tags

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
  depends_on                   = [azurerm_virtual_machine_extension.cloud_config_status]
}