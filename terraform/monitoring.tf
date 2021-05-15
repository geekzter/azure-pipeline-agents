resource azurerm_storage_account diagnostics {
  name                         = "${substr(lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/","")),0,15)}${local.suffix}diag"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_blob_public_access     = true
  enable_https_traffic_only    = true

  tags                         = local.tags
}
resource azurerm_log_analytics_workspace monitor {
  name                         = "${azurerm_resource_group.rg.name}-loganalytics"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  sku                          = "PerGB2018"
  retention_in_days            = 30

  tags                         = local.tags
}
resource azurerm_monitor_diagnostic_setting monitor {
  name                         = "${azurerm_log_analytics_workspace.monitor.name}-diagnostics"
  target_resource_id           = azurerm_log_analytics_workspace.monitor.id
  storage_account_id           = azurerm_storage_account.diagnostics.id

  log {
    category                   = "Audit"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
}
resource azurerm_log_analytics_solution solution {
  solution_name                 = each.value
  location                      = azurerm_log_analytics_workspace.monitor.location
  resource_group_name           = azurerm_resource_group.rg.name
  workspace_resource_id         = azurerm_log_analytics_workspace.monitor.id
  workspace_name                = azurerm_log_analytics_workspace.monitor.name

  plan {
    publisher                   = "Microsoft"
    product                     = "OMSGallery/${each.value}"
  }

  for_each                      = toset([
    "ServiceMap",
    "VMInsights",
  ])
} 