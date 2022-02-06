resource azurerm_storage_account images {
  name                         = "${substr(lower(replace(azurerm_resource_group.peer_rg.name,"/a|e|i|o|u|y|-/","")),0,15)}packer"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.peer_rg.name
  account_kind                 = "StorageV2"
  account_tier                 = "Premium"
  account_replication_type     = "LRS"
  allow_blob_public_access     = false
  enable_https_traffic_only    = true

  tags                         = var.tags
}

resource azurerm_private_dns_zone blob {
  name                         = "privatelink.blob.core.windows.net"
  resource_group_name          = azurerm_resource_group.peer_rg.name

  tags                         = var.tags
}
resource azurerm_private_dns_zone_virtual_network_link blob {
  name                         = "${azurerm_virtual_network.packer.name}-dns-blob"
  resource_group_name          = azurerm_resource_group.peer_rg.name
  private_dns_zone_name        = azurerm_private_dns_zone.blob.name
  virtual_network_id           = azurerm_virtual_network.packer.id

  tags                         = var.tags
}

resource azurerm_private_endpoint images_blob_storage_endpoint {
  name                         = "${azurerm_storage_account.images.name}-blob-endpoint"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.peer_rg.name
  
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.id

  private_dns_zone_group {
    name                       = split("/",azurerm_private_dns_zone.blob.id)[8]
    private_dns_zone_ids       = [azurerm_private_dns_zone.blob.id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_storage_account.images.name}-blob-endpoint-connection"
    private_connection_resource_id = azurerm_storage_account.images.id
    subresource_names          = ["blob"]
  }

  tags                         = var.tags
}