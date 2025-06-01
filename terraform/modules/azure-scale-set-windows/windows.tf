locals {
  host_configuration_script    = templatefile("${path.root}/../scripts/host/host_configuration.ps1",
    {
      diagnostics_directory    = "C:\\agent\\_diag"
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
    storage_account_uri        = null # Managed Storage Account
  }

  custom_data                  = var.prepare_host ? base64encode(local.host_configuration_script) : null

  identity {
    type                       = "SystemAssigned, UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
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
      name                     = "AzureMonitorWindowsAgent"
      publisher                = "Microsoft.Azure.Monitor"
      type                     = "AzureMonitorWindowsAgent"
      type_handler_version     = "1.30"
      auto_upgrade_minor_version= true
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
        "AzureMonitorWindowsAgent"
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
        "AzureMonitorWindowsAgent"
      ]
    }
  }    
  dynamic "extension" {
    for_each = range(var.prepare_host ? 1 : 0)
    content {
      # name                     = "PostGenerationScript"
      name                     = "HostConfigurationScript"
      publisher                = "Microsoft.Compute"
      type                     = "CustomScriptExtension"
      type_handler_version     = "1.10"
      # publisher                = "Microsoft.Azure.Extensions"
      # type                     = "CustomScript"
      # type_handler_version     = "2.1"
      auto_upgrade_minor_version= true
      protected_settings       = jsonencode({
        # https://github.com/actions/runner-images/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
        # "commandToExecute"     = "powershell.exe -ExecutionPolicy Unrestricted -Command \"if (Test-Path C:/post-generation) {Get-ChildItem C:/post-generation -Filter *.ps1 | ForEach-Object { & $_.FullName }}\""
        "commandToExecute"     = "powershell.exe -ExecutionPolicy Unrestricted -Command \"Copy-Item C:/AzureData/CustomData.bin ./host_configuration.ps1 -Force;./host_configuration.ps1 *> C:/WindowsAzure/Logs/host_configuration.log\""
      })

      provision_after_extensions= var.deploy_non_essential_vm_extensions ? [
        "AzureMonitorWindowsAgent",
        "DAExtension",
        "AzureNetworkWatcherExtension"
      ] : null
    }
  }    

  lifecycle {
    ignore_changes             = [
      # custom_data,
      extension,
      instances,
      tags["__AzureDevOpsElasticPool"],
      tags["__AzureDevOpsElasticPoolTimeStamp"]
    ]
  }
  tags                         = var.tags
}

resource azurerm_monitor_diagnostic_setting windows_agents {
  name                         = "${azurerm_windows_virtual_machine_scale_set.windows_agents.name}-logs"
  target_resource_id           = azurerm_windows_virtual_machine_scale_set.windows_agents.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  enabled_metric {
    category                   = "AllMetrics"
  }
} 