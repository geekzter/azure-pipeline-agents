output shared_image_gallery_id {
  value                        = local.shared_image_gallery_id
}

output storage_account_id {
  value                        = azurerm_storage_account.vhds.id
}
output storage_account_name {
  value                        = azurerm_storage_account.vhds.name
}
output storage_container_id {
  value                        = azurerm_storage_container.vhds.id
}
output storage_container_name {
  value                        = azurerm_storage_container.vhds.name
}