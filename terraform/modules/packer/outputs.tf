output shared_image_gallery_id {
  value                        = local.shared_image_gallery_id
}

output storage_account_id {
  value                        = azurerm_storage_account.vhds.id
}
output storage_account_name {
  value                        = azurerm_storage_account.vhds.name
}