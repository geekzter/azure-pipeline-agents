data cloudinit_config user_data {
  gzip                         = false
  base64_encode                = false

  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-userdata.yaml",
    {
      subnet_id                = var.subnet_id
      virtual_network_id       = local.virtual_network_id
    })
    content_type               = "text/cloud-config"
  }
}

locals {
  linux_pipeline_agent_name    = var.linux_pipeline_agent_name != "" ? "${lower(var.linux_pipeline_agent_name)}-${terraform.workspace}" : local.linux_vm_name
  linux_vm_name                = "${var.linux_vm_name_prefix}-${terraform.workspace}-${var.suffix}"
}

resource azurerm_public_ip linux_pip {
  name                         = "${local.linux_vm_name}${count.index+1}-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags
  count                        = var.linux_agent_count
}

resource azurerm_network_interface linux_nic {
  name                         = "${local.linux_vm_name}${count.index+1}-nic"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id       = azurerm_public_ip.linux_pip[count.index].id
  }
  enable_accelerated_networking = var.vm_accelerated_networking

  tags                         = var.tags
  count                        = var.linux_agent_count
}

resource azurerm_network_security_rule admin_ssh {
  name                         = "AdminSSH${count.index+1}"
  # # Use unique names to force replacement and get just-in-time deployment access
  # name                         = "AdminSSH-${formatdate("YYYYMMDDhhmmss",timestamp())}-${count.index+1}" 
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

  depends_on                   = [
    null_resource.cloud_config_status # Close this port once we have obtained cloud init status via remote-provisioner
  ]
}

resource azurerm_network_security_rule terraform_ssh {
  name                         = "TerraformSSH"
  priority                     = 299
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefix        = var.terraform_cidr
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name
}

resource azurerm_network_interface_security_group_association linux_nic_nsg {
  network_interface_id         = azurerm_network_interface.linux_nic[count.index].id
  network_security_group_id    = azurerm_network_security_group.nsg.id

  count                        = var.linux_agent_count
}

resource azurerm_linux_virtual_machine linux_agent {
  name                         = "${local.linux_vm_name}${count.index+1}"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  size                         = var.linux_vm_size
  admin_username               = var.user_name
  admin_password               = var.user_password
  custom_data                  = base64encode(data.cloudinit_config.user_data.rendered)
  disable_password_authentication = false
  network_interface_ids        = [azurerm_network_interface.linux_nic[count.index].id]

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  boot_diagnostics {
    storage_account_uri        = "${data.azurerm_storage_account.diagnostics.primary_blob_endpoint}${var.diagnostics_storage_sas}"
  }

  os_disk {
    caching                    = "ReadWrite"
    storage_account_type       = var.linux_storage_type
  }

  source_image_reference {
    publisher                  = var.linux_os_publisher
    offer                      = var.linux_os_offer
    sku                        = var.linux_os_sku
    version                    = "latest"
  }

  tags                         = var.tags
  count                        = var.linux_agent_count
  depends_on                   = [azurerm_network_interface_security_group_association.linux_nic_nsg]
}

resource azurerm_virtual_machine_extension cloud_config_status {
  name                         = "CloudConfigStatusScript"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent[count.index].id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  settings                     = jsonencode({
    "commandToExecute"         = "/usr/bin/cloud-init status --long --wait ; systemctl status cloud-final.service --full --no-pager --wait"
  })

  tags                         = var.tags

  count                        = var.linux_agent_count
}
resource azurerm_virtual_machine_extension linux_log_analytics {
  name                         = "OmsAgentForLinux"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent[count.index].id
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

  count                        = var.linux_agent_count
  depends_on                   = [azurerm_virtual_machine_extension.cloud_config_status]
}
resource azurerm_virtual_machine_extension linux_dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent[count.index].id
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

  count                        = var.linux_agent_count
  depends_on                   = [azurerm_virtual_machine_extension.cloud_config_status]
}
resource azurerm_virtual_machine_extension linux_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent[count.index].id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentLinux"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  tags                         = var.tags

  count                        = var.linux_agent_count
  depends_on                   = [azurerm_virtual_machine_extension.cloud_config_status]
}

resource null_resource cloud_config_status {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    # Start VM, so we can execute script through SSH
    command                    = "az vm start --ids ${azurerm_linux_virtual_machine.linux_agent[count.index].id}"
  }

  # Bootstrap using https://github.com/geekzter/bootstrap-os/tree/master/linux
  provisioner remote-exec {
    inline                     = [
      "echo -n 'waiting for cloud-init to complete'",
      "/usr/bin/cloud-init status --long --wait >/dev/null", # Let Terraform print progress
      "systemctl status cloud-final.service --full --no-pager --wait"
    ]

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = var.user_password
      host                     = azurerm_public_ip.linux_pip[count.index].ip_address
    }
  }

  count                        = var.linux_agent_count
  depends_on                   = [
    azurerm_virtual_machine_extension.cloud_config_status,
    azurerm_virtual_machine_extension.linux_log_analytics,
    azurerm_virtual_machine_extension.linux_dependency_monitor,
    azurerm_virtual_machine_extension.linux_watcher,
    azurerm_network_interface_security_group_association.linux_nic_nsg
  ]
}

resource null_resource linux_pipeline_agent {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner "file" {
    source                     = "${path.root}/../scripts/agent/install_agent.sh"
    destination                = "~/install_agent.sh"

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = var.user_password
      host                     = azurerm_public_ip.linux_pip[count.index].ip_address
    }
  }

  provisioner remote-exec {
    inline                     = [
      "echo ${var.user_password} | sudo -S apt-get update -y",
      # We need dos2unix (depending on where we're uploading from) before we run the script, so install script pre-requisites inline here
      "sudo apt-get -y install curl dos2unix jq sed", 
      "dos2unix ~/install_agent.sh",
      "chmod +x ~/install_agent.sh",
      "~/install_agent.sh --agent-name ${local.linux_pipeline_agent_name}${count.index+1} --agent-pool ${var.linux_pipeline_agent_pool} --org ${var.devops_org} --pat ${var.devops_pat}"
    ]

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = var.user_password
      host                     = azurerm_public_ip.linux_pip[count.index].ip_address
    }
  }

  count                        = var.linux_agent_count
  depends_on                   = [
    azurerm_virtual_machine_extension.cloud_config_status,
    azurerm_virtual_machine_extension.linux_log_analytics,
    azurerm_virtual_machine_extension.linux_dependency_monitor,
    azurerm_virtual_machine_extension.linux_watcher,
    azurerm_network_interface_security_group_association.linux_nic_nsg,
    # null_resource.cloud_config_status
  ]  
}