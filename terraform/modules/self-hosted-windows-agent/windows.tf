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

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id       = azurerm_public_ip.windows_pip.id
  }
  enable_accelerated_networking = var.vm_accelerated_networking

  tags                         = var.tags
}

resource azurerm_network_security_rule rdp {
  name                         = "AdminRDP${count.index+1}"
  priority                     = count.index+202
  direction                    = "Inbound"
  access                       = var.public_access_enabled ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "3389"
  source_address_prefix        = var.admin_cidr_ranges[count.index]
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name

  count                        = length(var.admin_cidr_ranges)
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
    storage_account_uri        = "${data.azurerm_storage_account.diagnostics.primary_blob_endpoint}${var.diagnostics_storage_sas}"
  }

  custom_data                  = base64encode(file("${path.root}/../scripts/agent/install_agent.ps1"))

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

  # Required for AAD Login
  identity {
    type                       = "SystemAssigned"
  }
  
  tags                         = var.tags
}
resource azurerm_virtual_machine_extension windows_log_analytics {
  name                         = "MMAExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "MicrosoftMonitoringAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
    "azureResourceId"          = azurerm_windows_virtual_machine.windows_agent.id
    "stopOnMultipleConnections"= "true"
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  tags                         = var.tags

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

resource azurerm_virtual_machine_extension pipeline_agent {
  name                         = "PipelineAgentCustomScript"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent.id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  auto_upgrade_minor_version   = true

  protected_settings           = jsonencode({
    "commandToExecute"         = "powershell.exe -ExecutionPolicy Unrestricted -Command \"Copy-Item C:/AzureData/CustomData.bin ./install_agent.ps1 -Force;./install_agent.ps1 -AgentName ${var.pipeline_agent_name} -AgentPool ${var.pipeline_agent_pool} -Organization ${var.devops_org} -PAT ${var.devops_pat} *> install_agent.log\""
  })

  # Start VM, so we can update/destroy the extension
  provisioner local-exec {
    command                    = "az vm start --ids ${self.virtual_machine_id}"
  }
  provisioner local-exec {
    when                       = destroy
    command                    = "az vm start --ids ${self.virtual_machine_id}"
  }

  depends_on                   = [
    azurerm_virtual_machine_extension.windows_log_analytics,
    azurerm_virtual_machine_extension.windows_dependency_monitor,
    azurerm_virtual_machine_extension.windows_watcher,
  ]
}