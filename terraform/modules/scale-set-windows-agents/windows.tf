resource azurerm_image vhd {
  name                         = "${var.resource_group_name}-linux-agents-image"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  os_disk {
    os_type                    = "Windows"
    os_state                   = "Generalized"
    blob_uri                   = var.windows_os_vhd_url
    size_gb                    = 100
  }

  count                        = (var.windows_os_vhd_url != null && var.windows_os_vhd_url != "") ? 1 : 0
}

resource azurerm_windows_virtual_machine_scale_set windows_agents {
  name                         = "${var.resource_group_name}-windows-agents"
  computer_name_prefix         = "winvmss"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  admin_username               = var.user_name
  admin_password               = var.user_password
  instances                    = var.windows_agent_count
  overprovision                = false
  sku                          = var.windows_vm_size
  upgrade_mode                 = "Manual"

  boot_diagnostics {
    storage_account_uri        = "${data.azurerm_storage_account.diagnostics.primary_blob_endpoint}${var.diagnostics_storage_sas}"
  }

  network_interface {
    name                       = "${var.resource_group_name}-windows-agents-nic"
    primary                    = true

    ip_configuration {
      name                     = "ipconfig"
      primary                  = true
      subnet_id                = var.subnet_id
    }
  }

  os_disk {
    storage_account_type       = var.windows_storage_type
    caching                    = "ReadWrite"
  }

  source_image_id              = (var.windows_os_vhd_url != null && var.windows_os_vhd_url != "") ? azurerm_image.vhd.0.id : null

  dynamic "source_image_reference" {
    for_each = range((var.windows_os_vhd_url != null && var.windows_os_vhd_url != "") ? 0 : 1) 
    content {
      publisher                = var.windows_os_publisher
      offer                    = var.windows_os_offer
      sku                      = var.windows_os_sku
      version                  = var.windows_os_version
    }
  }    

  lifecycle {
    ignore_changes             = [
      instances,
    ]
  }
  tags                         = var.tags
}

resource azurerm_virtual_machine_scale_set_extension windows_log_analytics {
  name                         = "MMAExtension"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.windows_agents.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "MicrosoftMonitoringAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
    "azureResourceId"          = azurerm_windows_virtual_machine_scale_set.windows_agents.id
    "stopOnMultipleConnections"= "true"
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}
resource azurerm_virtual_machine_scale_set_extension windows_dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.windows_agents.id
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

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}
resource azurerm_virtual_machine_scale_set_extension windows_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.windows_agents.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentWindows"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true


  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting windows_agents {
  name                         = "${azurerm_windows_virtual_machine_scale_set.windows_agents.name}-logs"
  target_resource_id           = azurerm_windows_virtual_machine_scale_set.windows_agents.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
} 