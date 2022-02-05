locals {
  pre_existing_gallery         = var.shared_image_gallery_id != null && var.shared_image_gallery_id != ""
  shared_image_gallery_id      = local.pre_existing_gallery ? var.shared_image_gallery_id : azurerm_shared_image_gallery.compute_gallery.0.id
}

resource azurerm_storage_account vhds {
  name                         = "${substr(lower(replace(var.resource_group_name,"/a|e|i|o|u|y|-/","")),0,15)}packer"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  account_kind                 = "StorageV2"
  account_tier                 = "Premium"
  account_replication_type     = "LRS"
  allow_blob_public_access     = false
  enable_https_traffic_only    = true

  tags                         = var.tags
}

resource azurerm_private_endpoint packer_blob_storage_endpoint {
  name                         = "${azurerm_storage_account.vhds.name}-blob-endpoint"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  
  subnet_id                    = var.subnet_id

  private_dns_zone_group {
    name                       = "privatelink.blob.core.windows.net" # split("/",var.blob_private_dns_zone_id)[8]
    private_dns_zone_ids       = [var.blob_private_dns_zone_id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_storage_account.vhds.name}-blob-endpoint-connection"
    private_connection_resource_id = azurerm_storage_account.vhds.id
    subresource_names          = ["blob"]
  }

  tags                         = var.tags
}

resource azurerm_shared_image_gallery compute_gallery {
  name                         = replace("${var.resource_group_name}-gallery","-",".")
  location                     = var.location
  resource_group_name          = var.resource_group_name
  description                  = "https://github.com/geekzter/azure-pipeline-agents (${terraform.workspace})"

  tags                         = var.tags

  count                        = local.pre_existing_gallery ? 0 : 1
}