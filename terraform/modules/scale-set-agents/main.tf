locals {
  log_analytics_workspace_name = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-1)
  log_analytics_workspace_rg   = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-5)
  scripts_container_name       = element(split("/",var.scripts_container_id),length(split("/",var.scripts_container_id))-1)
  scripts_storage_name         = element(split(".",element(split("/",var.scripts_container_id),length(split("/",var.scripts_container_id))-2)),0)
}

data azurerm_log_analytics_workspace monitor {
  name                         = local.log_analytics_workspace_name
  resource_group_name          = local.log_analytics_workspace_rg
}
