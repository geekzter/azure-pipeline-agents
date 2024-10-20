data cloudinit_config user_data {
  gzip                         = false
  base64_encode                = false

  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-post-generation.yaml",
    {
      user_name                = var.user_name
    })
    content_type               = "text/cloud-config"
    merge_type                 = "list(append)+dict(recurse_array)+str()"
  }
  dynamic "part" {
    for_each = range(var.install_tools ? 1 : 0)
    content {
      content                  = templatefile("${path.root}/../cloudinit/cloud-config-tools.yaml",
      {
        outbound_ip            = var.outbound_ip_address
        subnet_id              = var.subnet_id
        virtual_network_id     = local.virtual_network_id
      })
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }  
  dynamic "part" {
    for_each = range(var.deploy_files_share ? 1 : 0)
    content {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-files-share.yaml",
      {
        diagnostics_directory  = "/var/opt/pipelines-agent/diag"
        smb_mount_point        = var.diagnostics_smb_share_mount_point
        smb_share              = var.diagnostics_smb_share
        storage_account_key    = data.azurerm_storage_account.files.0.primary_access_key
        storage_account_name   = data.azurerm_storage_account.files.0.name
        user                   = var.user_name
      })
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }
  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-userdata.yaml",
    {
      user_name                = var.user_name
      environment              = var.environment_variables
    })
    content_type               = "text/cloud-config"
    merge_type                 = "list(append)+dict(recurse_array)+str()"
  }
  # Azure Log Analytics VM extension fails on https://github.com/actions/runner-images
  dynamic "part" {
    for_each = range(var.deploy_non_essential_vm_extensions ? 1 : 0)
    content {
      content                  = templatefile("${path.root}/../cloudinit/cloud-config-log-analytics.yaml",
      {
        workspace_id           = data.azurerm_log_analytics_workspace.monitor.workspace_id
        workspace_key          = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
      })
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }
  dynamic "part" {
    for_each = range(var.deploy_agent ? 1 : 0)
    content {
      content                  = templatefile("${path.root}/../cloudinit/cloud-config-agent.yaml",
      {
        agent_name             = var.azdo_pipeline_agent_name
        agent_pool             = var.azdo_pipeline_agent_pool != null ? var.azdo_pipeline_agent_pool : ""
        agent_version_id       = var.azdo_pipeline_agent_version_id
        deployment_group       = var.azdo_deployment_group_name != null ? var.azdo_deployment_group_name : ""
        environment            = var.azdo_environment_name != null ? var.azdo_environment_name : ""
        install_agent_script_b64= filebase64("${path.root}/../scripts/host/install_agent.sh")
        project                = var.azdo_project
        org                    = var.azdo_org
        pat                    = var.azdo_pat
        user                   = var.user_name
      })
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }

  count                        = var.deploy_agent || var.prepare_host ? 1 : 0
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

  dynamic "ip_configuration" {
    for_each = range(var.create_public_ip_address ? 1 : 0) 
    content {
      name                     = "ipconfig"
      subnet_id                = var.subnet_id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id     = azurerm_public_ip.linux_pip.id
    }
  }  

  dynamic "ip_configuration" {
    for_each = range(var.create_public_ip_address ? 0 : 1) 
    content {
      name                     = "ipconfig"
      subnet_id                = var.subnet_id
      private_ip_address_allocation = "Dynamic"
    }
  }  

  accelerated_networking_enabled = var.vm_accelerated_networking

  tags                         = var.tags
}

resource azurerm_network_security_rule admin_ssh {
  name                         = "AdminSSH"
  priority                     = 201
  direction                    = "Inbound"
  access                       = var.enable_public_access ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefixes = [
    azurerm_public_ip.linux_pip.ip_address,
    azurerm_network_interface.linux_nic.ip_configuration.0.private_ip_address
  ]
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name
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
  allow_extension_operations   = var.deploy_non_essential_vm_extensions || var.deploy_agent || var.prepare_host
  custom_data                  = var.deploy_agent || var.prepare_host ? base64encode(data.cloudinit_config.user_data.0.rendered) : null
  disable_password_authentication = false
  network_interface_ids        = [azurerm_network_interface.linux_nic.id]
  provision_vm_agent           = var.deploy_non_essential_vm_extensions || var.deploy_agent || var.prepare_host

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  boot_diagnostics {
    storage_account_uri        = null # Managed Storage Account
  }

  identity {
    type                       = "SystemAssigned, UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }
  
  os_disk {
    name                       = "${var.name}-osdisk"
    caching                    = "ReadWrite"
    storage_account_type       = var.storage_type
  }

  source_image_id              = var.os_image_id

  dynamic "source_image_reference" {
    for_each = range(var.os_image_id == null || var.os_image_id == "" ? 1 : 0) 
    content {
      publisher                = var.os_publisher
      offer                    = var.os_offer
      sku                      = var.os_sku
      version                  = var.os_version
    }
  }    

  lifecycle {
    ignore_changes             = [
      custom_data,
      source_image_id,
      source_image_reference.0.version,
    ]
  }  

  tags                         = var.tags
  depends_on                   = [azurerm_network_interface_security_group_association.linux_nic_nsg]

  # Terraform azurerm does not allow disk access configuration of OS disk
  # BUG: https://github.com/Azure/azure-cli/issues/19455 
  #      So use disk_access_name instead of disk_access_id
  provisioner local-exec {
    command                    = "az disk update --name ${var.name}-osdisk --resource-group ${self.resource_group_name} --disk-access ${var.disk_access_name} --network-access-policy AllowPrivate --query 'networkAccessPolicy'"
  }  
}

resource azurerm_virtual_machine_extension cloud_config_status {
  name                         = "CloudConfigStatusScript"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.1"
  auto_upgrade_minor_version   = true
  settings                     = jsonencode({
    "commandToExecute"         = "/usr/bin/cloud-init status --long --wait ; systemctl status cloud-final.service --full --no-pager --wait"
  })
  tags                         = var.tags

  timeouts {
    create                     = "60m"
  }  
}

resource azurerm_virtual_machine_extension linux_monitor {
  name                         = "AzureMonitorLinuxAgent"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorLinuxAgent"
  type_handler_version         = "1.33"
  auto_upgrade_minor_version   = true

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
  tags                         = var.tags

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
  depends_on                   = [
    azurerm_virtual_machine_extension.cloud_config_status,
    azurerm_virtual_machine_extension.linux_monitor
  ]
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
  depends_on                   = [
    azurerm_virtual_machine_extension.cloud_config_status,
    azurerm_virtual_machine_extension.linux_monitor
  ]
}
resource azurerm_virtual_machine_extension policy {
  name                         = "AzurePolicyforLinux"
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent.id
  publisher                    = "Microsoft.GuestConfiguration"
  type                         = "ConfigurationforLinux"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  tags                         = var.tags

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
  depends_on                   = [
    azurerm_virtual_machine_extension.cloud_config_status,
    azurerm_virtual_machine_extension.linux_monitor
  ]
}

resource azurerm_dev_test_global_vm_shutdown_schedule auto_shutdown {
  virtual_machine_id           = azurerm_linux_virtual_machine.linux_agent.id
  location                     = azurerm_linux_virtual_machine.linux_agent.location
  enabled                      = true

  daily_recurrence_time        = replace(var.shutdown_time,":","")
  timezone                     = var.timezone

  notification_settings {
    enabled                    = false
  }

  tags                         = var.tags
  count                        = var.shutdown_time != null && var.shutdown_time != "" ? 1 : 0
}