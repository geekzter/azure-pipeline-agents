output storage_account_id {
  value                        = azurerm_storage_account.packer_storage.id
}
output storage_account_name {
  value                        = azurerm_storage_account.packer_storage.name
}