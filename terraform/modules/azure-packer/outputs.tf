output build_resource_group_id {
  value                        = azurerm_resource_group.build.id
}

output build_resource_ids {
  value                        = data.azurerm_resources.build_resources.resources[*].id
}

output network_resource_group_id {
  value                        = azurerm_resource_group.network.id
}

output packer_subnet_name {
  value                        = azurerm_subnet.packer.name
}

output virtual_network_id {
  value                        = azurerm_virtual_network.packer.id
}

output policy_set_name {
  value                        = try(azurerm_policy_set_definition.build_policies.0.name,null)
}