output packer_subnet_name {
  value                        = azurerm_subnet.packer.name
}

output policy_identity_id {
  value                        = azurerm_user_assigned_identity.policy.id
}

output policy_identity_client_id {
  value                        = azurerm_user_assigned_identity.policy.client_id
}
output policy_identity_name {
  value                        = azurerm_user_assigned_identity.policy.name
}
output policy_identity_principal_id {
  value                        = azurerm_user_assigned_identity.policy.principal_id
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
  value                        = azurerm_policy_set_definition.build_policies.name
}