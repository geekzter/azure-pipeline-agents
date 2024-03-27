locals {
  storage_contributors         = distinct(
    concat(
      var.storage_contributors,
      [
        data.azuread_client_config.default.object_id
      ]
    )
  )
}

resource azurerm_role_assignment agent_storage_contributors {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Storage Blob Data Contributor"
  principal_id                 = each.value

  for_each                     = var.configure_access_control ? toset(local.storage_contributors) : toset([])
}
resource azurerm_role_assignment agent_file_storage_contributors {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Storage File Data Privileged Contributor"
  principal_id                 = each.value

  for_each                     = var.configure_access_control && var.deploy_azure_files_share ? toset(local.storage_contributors) : toset([])
}
resource azurerm_role_assignment packer_storage_contributors {
  scope                        = module.packer.0.network_resource_group_id
  role_definition_name         = "Storage Blob Data Contributor"
  principal_id                 = each.value

  for_each                     = var.create_azure_packer_infrastructure && var.configure_access_control ? toset(local.storage_contributors) : toset([])
}

resource azurerm_role_assignment agent_viewer {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Reader"
  principal_id                 = each.key

  for_each                     = var.configure_access_control ? toset(var.demo_viewers) : toset([])
}

resource azurerm_role_assignment build_viewer {
  scope                        = module.packer.0.build_resource_group_id
  role_definition_name         = "Reader"
  principal_id                 = each.key

  for_each                     = var.create_azure_packer_infrastructure && var.configure_access_control ? toset(var.demo_viewers) : toset([])
}
resource azurerm_role_assignment network_viewer {
  scope                        = module.packer.0.network_resource_group_id
  role_definition_name         = "Reader"
  principal_id                 = each.key

  for_each                     = var.create_azure_packer_infrastructure && var.configure_access_control ? toset(var.demo_viewers) : toset([])
}

resource azurerm_role_assignment vm_admin {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Virtual Machine Administrator Login"
  principal_id                 = var.azure_admin_object_id != null ? var.azure_admin_object_id : data.azuread_client_config.default.object_id

  count                        = var.configure_access_control ? 1 : 0
}

resource azurerm_role_assignment vm_contributor {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Virtual Machine Contributor"
  principal_id                 = var.azure_admin_object_id != null ? var.azure_admin_object_id : data.azuread_client_config.default.object_id

  count                        = var.configure_access_control ? 1 : 0
}

resource azurerm_user_assigned_identity agents {
  name                         = "${azurerm_resource_group.rg.name}-agent-identity"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location

  tags                         = local.tags
}

resource azurerm_role_assignment scale_set_service_connection {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Virtual Machine Contributor"
  principal_id                 = module.service_principal.0.principal_id

  count                        = var.configure_access_control && local.create_azdo_resources && local.create_azdo_service_connection ? 1 : 0
}