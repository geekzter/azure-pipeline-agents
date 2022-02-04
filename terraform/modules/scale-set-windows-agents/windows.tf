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
    enable_accelerated_networking = var.vm_accelerated_networking
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

  source_image_id              = var.windows_os_image_id

  dynamic "source_image_reference" {
    for_each = range(var.windows_os_image_id == null || var.windows_os_image_id == "" ? 1 : 0) 
    content {
      publisher                = var.windows_os_publisher
      offer                    = var.windows_os_offer
      sku                      = var.windows_os_sku
      version                  = var.windows_os_version
    }
  }  
  
  dynamic "extension" {
    for_each = range(var.deploy_non_essential_vm_extensions ? 1 : 0)
    content {
      name                     = "MMAExtension"
      publisher                = "Microsoft.EnterpriseCloud.Monitoring"
      type                     = "MicrosoftMonitoringAgent"
      type_handler_version     = "1.0"
      auto_upgrade_minor_version= true

      settings                 = jsonencode({
        "workspaceId"          = data.azurerm_log_analytics_workspace.monitor.workspace_id
        "stopOnMultipleConnections"= "true"
      })
      protected_settings       = jsonencode({
        "workspaceKey"         = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
      })
    }
  }    
  dynamic "extension" {
    for_each = range(var.deploy_non_essential_vm_extensions ? 1 : 0)
    content {
      name                     = "DAExtension"
      publisher                = "Microsoft.Azure.Monitoring.DependencyAgent"
      type                     = "DependencyAgentWindows"
      type_handler_version     = "9.5"
      auto_upgrade_minor_version= true

      settings                 = jsonencode({
        "workspaceId"          = data.azurerm_log_analytics_workspace.monitor.workspace_id
      })
      protected_settings       = jsonencode({
        "workspaceKey"         = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
      })

      provision_after_extensions= [
        "MMAExtension"
      ]
    }
  }    
  dynamic "extension" {
    for_each = range(var.deploy_non_essential_vm_extensions ? 1 : 0)
    content {
      name                     = "AzureNetworkWatcherExtension"
      publisher                = "Microsoft.Azure.NetworkWatcher"
      type                     = "NetworkWatcherAgentWindows"
      type_handler_version     = "1.4"
      auto_upgrade_minor_version= true

      provision_after_extensions= [
        "MMAExtension"
      ]
    }
  }    
  dynamic "extension" {
    for_each = range(var.prepare_host ? 1 : 0)
    content {
      name                     = "PostGenerationScript"
      publisher                = "Microsoft.Compute"
      type                     = "CustomScriptExtension"
      type_handler_version     = "1.10"
      # publisher                = "Microsoft.Azure.Extensions"
      # type                     = "CustomScript"
      # type_handler_version     = "2.1"
      auto_upgrade_minor_version= true
      protected_settings       = jsonencode({
        # https://github.com/actions/virtual-environments/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
        "commandToExecute"     = "powershell.exe -ExecutionPolicy Unrestricted -Command \"if (Test-Path C:/post-generation) {Get-ChildItem C:/post-generation -Filter *.ps1 | ForEach-Object { & $_.FullName }}\""
      })

      provision_after_extensions= [
        "MMAExtension",
        "DAExtension",
        "AzureNetworkWatcherExtension"
      ]
    }
  }    

  lifecycle {
    ignore_changes             = [
      extension,
      instances,
    ]
  }
  tags                         = var.tags
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