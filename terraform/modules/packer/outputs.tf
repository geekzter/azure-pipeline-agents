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