locals {
  azdo_deployment_group_name   = var.azdo_deployment_group_name != null ? var.azdo_deployment_group_name : ""
  azdo_environment_name        = var.azdo_environment_name != null ? var.azdo_environment_name : ""
  azdo_pipeline_agent_pool     = var.azdo_pipeline_agent_pool != null ? var.azdo_pipeline_agent_pool : ""
  prepare_agent_script         = templatefile("${path.root}/../scripts/host/prepare_agent.ps1",
    {
      diagnostics_directory    = "C:\\ProgramData\\pipeline-agent\\diag"
      drive_letter             = "X"
      environment              = var.environment_variables
      smb_fqdn                 = var.diagnostics_smb_share != null ? replace(var.diagnostics_smb_share,"/","") : ""
      smb_share                = var.diagnostics_smb_share != null ? replace(var.diagnostics_smb_share,"/","\\") : ""
      storage_account_key      = var.diagnostics_smb_share != null ? data.azurerm_storage_account.files.0.primary_access_key : ""
      storage_account_name     = var.diagnostics_smb_share != null ? data.azurerm_storage_account.files.0.name : ""
      storage_share_host       = var.diagnostics_smb_share != null ? data.azurerm_storage_account.files.0.primary_file_host : ""
      user_name                = var.user_name
    }
  )
}

resource azurerm_public_ip windows_pip {
  name                         = "${var.name}-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags
}

resource azurerm_network_interface windows_nic {
  name                         = "${var.name}-nic"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  dynamic "ip_configuration" {
    for_each = range(var.create_public_ip_address ? 1 : 0) 
    content {
      name                     = "ipconfig"
      subnet_id                = var.subnet_id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id     = azurerm_public_ip.windows_pip.id
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

resource azurerm_network_security_rule rdp {
  name                         = "AdminRDP"
  priority                     = 202
  direction                    = "Inbound"
  access                       = var.enable_public_access ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "3389"
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefixes = [
    azurerm_public_ip.windows_pip.ip_address,
    azurerm_network_interface.windows_nic.ip_configuration.0.private_ip_address
  ]
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name
}

resource azurerm_network_interface_security_group_association windows_nic_nsg {
  network_interface_id         = azurerm_network_interface.windows_nic.id
  network_security_group_id    = azurerm_network_security_group.nsg.id
}

resource azurerm_windows_virtual_machine windows_agent {
  name                         = var.name
  computer_name                = var.computer_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  network_interface_ids        = [azurerm_network_interface.windows_nic.id]
  size                         = var.vm_size
  admin_username               = var.user_name
  admin_password               = var.user_password

  boot_diagnostics {
    storage_account_uri        = null # Managed Storage Account
  }

  custom_data                  = var.deploy_agent_vm_extension ? base64encode(local.prepare_agent_script) : null
  allow_extension_operations   = var.deploy_agent_vm_extension || var.deploy_non_essential_vm_extensions
  provision_vm_agent           = var.deploy_agent_vm_extension || var.deploy_non_essential_vm_extensions

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

  identity {
    type                       = "SystemAssigned, UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  lifecycle {
    ignore_changes             = [
      custom_data,
      source_image_id,
      source_image_reference.0.version,
    ]
  }    
  
  tags                         = var.tags

  # Terraform azurerm does not allow disk access configuration of OS disk
  # BUG: https://github.com/Azure/azure-cli/issues/19455 
  #      So use disk_access_name instead of disk_access_id
  provisioner local-exec {
    command                    = "az disk update --name ${var.name}-osdisk --resource-group ${self.resource_group_name} --disk-access ${var.disk_access_name} --network-access-policy AllowPrivate --query 'networkAccessPolicy'"
  }  

  depends_on                   = [azurerm_network_interface_security_group_association.windows_nic_nsg]
}
resource azurerm_virtual_machine_extension azure_monitor {
  name                         = "AzureMonitorWindowsAgent"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorWindowsAgent"
  type_handler_version         = "1.30"
  auto_upgrade_minor_version   = true

  tags                         = var.tags
  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}
resource null_resource prepare_log_analytics {
  triggers                     = {
    vm                         = azurerm_windows_virtual_machine.windows_agent.id
  }

  provisioner local-exec {
    command                    = "${path.root}/../scripts/remove_vm_extension.ps1 -VmName ${azurerm_windows_virtual_machine.windows_agent.name} -ResourceGroupName ${var.resource_group_name} -Publisher Microsoft.EnterpriseCloud.Monitoring -ExtensionType MicrosoftMonitoringAgent -SkipExtensionName OmsAgentForMe"
    interpreter                = ["pwsh","-nop","-command"]
  }

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}

resource azurerm_virtual_machine_extension windows_dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent.id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentWindows"
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
                                  azurerm_virtual_machine_extension.azure_monitor
  ] 
}
resource azurerm_virtual_machine_extension windows_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentWindows"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  tags                         = var.tags

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}
resource azurerm_virtual_machine_extension policy {
  name                         = "AzurePolicyforWindows"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent.id
  publisher                    = "Microsoft.GuestConfiguration"
  type                         = "ConfigurationforWindows"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  tags                         = var.tags

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}

resource azurerm_virtual_machine_extension pipeline_agent {
  name                         = "PipelineAgentCustomScript"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent.id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  # publisher                    = "Microsoft.Azure.Extensions"
  # type                         = "CustomScript"
  # type_handler_version         = "2.1"
  auto_upgrade_minor_version   = true

  protected_settings           = jsonencode({
    "commandToExecute"         = "powershell.exe -ExecutionPolicy Unrestricted -Command \"Copy-Item C:/AzureData/CustomData.bin ./prepare_agent.ps1 -Force;./prepare_agent.ps1 -AgentName ${var.azdo_pipeline_agent_name} -AgentPool '${local.azdo_pipeline_agent_pool}' -DeploymentGroup '${local.azdo_deployment_group_name}' -Environment '${local.azdo_environment_name}' -AgentVersionId ${var.azdo_pipeline_agent_version_id} -Organization ${var.azdo_org} -PAT ${var.azdo_pat} -Project '${var.azdo_project}' *> C:/WindowsAzure/Logs/prepare_agent.log\""
  })

  # Start VM, so we can update/destroy the extension
  provisioner local-exec {
    command                    = "az vm start --ids ${self.virtual_machine_id}"
  }
  provisioner local-exec {
    when                       = destroy
    command                    = "az vm start --ids ${self.virtual_machine_id}"
  }

  tags                         = var.tags

  count                        = var.deploy_agent_vm_extension ? 1 : 0
  depends_on                   = [
    azurerm_virtual_machine_extension.azure_monitor,
    azurerm_virtual_machine_extension.windows_dependency_monitor,
    azurerm_virtual_machine_extension.windows_watcher,
  ]
}

resource azurerm_dev_test_global_vm_shutdown_schedule auto_shutdown {
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent.id
  location                     = azurerm_windows_virtual_machine.windows_agent.location
  enabled                      = true

  daily_recurrence_time        = replace(var.shutdown_time,":","")
  timezone                     = var.timezone

  notification_settings {
    enabled                    = false
  }

  tags                         = var.tags
  count                        = var.shutdown_time != null && var.shutdown_time != "" ? 1 : 0
}