locals {
  log_analytics_workspace_id   = var.azure_log_analytics_workspace_id != "" && var.azure_log_analytics_workspace_id != null ? var.azure_log_analytics_workspace_id : azurerm_log_analytics_workspace.monitor.0.id
}



resource azurerm_log_analytics_workspace monitor {
  name                         = "${azurerm_resource_group.rg.name}-loganalytics"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  sku                          = "PerGB2018"
  retention_in_days            = 30

  count                        = var.azure_log_analytics_workspace_id != "" && var.azure_log_analytics_workspace_id != null ? 0 : 1
  tags                         = local.tags
}
resource azurerm_monitor_diagnostic_setting monitor {
  name                         = "${azurerm_log_analytics_workspace.monitor.0.name}-diagnostics"
  target_resource_id           = azurerm_log_analytics_workspace.monitor.0.id
  storage_account_id           = azurerm_storage_account.diagnostics.id

  enabled_log {
    category                   = "Audit"
  }
  enabled_metric {
    category                   = "AllMetrics"
  }
  count                        = var.azure_log_analytics_workspace_id != "" && var.azure_log_analytics_workspace_id != null ? 0 : 1
}
resource azurerm_log_analytics_solution solution {
  solution_name                 = each.value
  location                      = azurerm_log_analytics_workspace.monitor.0.location
  resource_group_name           = azurerm_resource_group.rg.name
  workspace_resource_id         = azurerm_log_analytics_workspace.monitor.0.id
  workspace_name                = azurerm_log_analytics_workspace.monitor.0.name

  plan {
    publisher                   = "Microsoft"
    product                     = "OMSGallery/${each.value}"
  }

  tags                         = local.tags

  for_each                     = var.azure_log_analytics_workspace_id == "" || var.azure_log_analytics_workspace_id == null ? toset([
    "ServiceMap",
    "VMInsights",
  ]) : toset([])
} 