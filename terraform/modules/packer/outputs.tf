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

output storage_account_id {
  value                        = azurerm_storage_account.images.id
}
output storage_account_name {
  value                        = azurerm_storage_account.images.name
}
output storage_blob_ip_address {
  value                        = azurerm_private_endpoint.images_blob_storage_endpoint.private_service_connection[0].private_ip_address
}

output virtual_network_id {
  value                        = azurerm_virtual_network.packer.id
}

output policy_set_name {
  value                        = azurerm_policy_set_definition.build_policies.0.name

  precondition {
    condition                  = var.configure_policy
    error_message              = "Policy not configured"
  }  
}