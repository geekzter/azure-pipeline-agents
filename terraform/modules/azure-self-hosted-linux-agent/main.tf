locals {
  log_analytics_workspace_name = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-1)
  log_analytics_workspace_rg   = element(split("/",var.log_analytics_workspace_resource_id),length(split("/",var.log_analytics_workspace_resource_id))-5)
  virtual_network_id           = join("/",slice(split("/",var.subnet_id),0,length(split("/",var.subnet_id))-2))
}

data azurerm_log_analytics_workspace monitor {
  name                         = local.log_analytics_workspace_name
  resource_group_name          = local.log_analytics_workspace_rg
}

data azurerm_storage_account files {
  name                         = split(".",split("/",var.diagnostics_smb_share)[2])[0]
  resource_group_name          = var.resource_group_name

  count                        = var.deploy_files_share ? 1 : 0
}

resource azurerm_network_security_group nsg {
  name                         = "${var.name}-nsg"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
}