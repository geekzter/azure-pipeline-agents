locals {
    storage_contributors       = distinct(
        concat(
            var.storage_contributors,
            [
                data.azurerm_client_config.default.object_id
            ]
        )
    )
}

resource azurerm_role_assignment agent_storage_contributors {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Storage Blob Data Contributor"
  principal_id                 = each.value

  for_each                     = toset(local.storage_contributors)
}
resource azurerm_role_assignment packer_storage_contributors {
  scope                        = module.packer.network_resource_group_id
  role_definition_name         = "Storage Blob Data Contributor"
  principal_id                 = each.value

  for_each                     = toset(local.storage_contributors)
}

resource azurerm_role_assignment service_principal_contributor {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Contributor"
  principal_id                 = module.service_principal.0.principal_id

  count                        = var.create_contributor_service_principal ? 1 : 0
}

resource azurerm_role_assignment agent_viewer {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Reader"
  principal_id                 = each.key

  for_each                     = toset(var.demo_viewers)
}

resource azurerm_role_assignment build_viewer {
  scope                        = module.packer.build_resource_group_id
  role_definition_name         = "Reader"
  principal_id                 = each.key

  for_each                     = toset(var.demo_viewers)
}
resource azurerm_role_assignment network_viewer {
  scope                        = module.packer.network_resource_group_id
  role_definition_name         = "Reader"
  principal_id                 = each.key

  for_each                     = toset(var.demo_viewers)
}

resource azurerm_user_assigned_identity agents {
  name                         = "${azurerm_resource_group.rg.name}-agent-identity"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
}