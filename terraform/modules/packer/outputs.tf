output virtual_network_id {
  value                        = azurerm_virtual_network.packer.id
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