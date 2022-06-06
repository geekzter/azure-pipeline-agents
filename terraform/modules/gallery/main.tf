locals {
  pre_existing_gallery         = var.shared_image_gallery_id != null && var.shared_image_gallery_id != ""
  shared_image_gallery_id      = local.pre_existing_gallery ? var.shared_image_gallery_id : azurerm_shared_image_gallery.compute_gallery.0.id
}

resource azurerm_storage_account vhds {
  name                         = "${substr(lower(replace(var.resource_group_name,"/a|e|i|o|u|y|-/","")),0,15)}${var.suffix}vhd"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  account_kind                 = "StorageV2"
  account_tier                 = "Premium"
  account_replication_type     = "LRS"
  allow_nested_items_to_be_public = false
  enable_https_traffic_only    = true

  tags                         = var.tags
}

resource azurerm_storage_container vhds {
  name                         = "vhds"
  storage_account_name         = azurerm_storage_account.vhds.name
  container_access_type        = "private"
}

resource azurerm_private_endpoint vhds_blob_storage_endpoint {
  name                         = "${azurerm_storage_account.vhds.name}-blob-endpoint"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  
  subnet_id                    = var.subnet_id

  private_dns_zone_group {
    name                       = split("/",var.blob_private_dns_zone_id)[8]
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

resource azurerm_storage_account_network_rules vhds {
  storage_account_id           = azurerm_storage_account.vhds.id

  default_action               = "Deny"
  ip_rules                     = var.admin_cidr_ranges
  bypass                       = [
                                  # "AzureServices", # required for azcopy (direct copy between storage accounts)
                                  "Metrics"
  ]
}

resource azurerm_shared_image_gallery compute_gallery {
  name                         = replace("${var.resource_group_name}-gallery","-",".")
  location                     = var.location
  resource_group_name          = var.resource_group_name
  description                  = "https://github.com/geekzter/azure-pipeline-agents (${terraform.workspace})"

  tags                         = var.tags

  count                        = local.pre_existing_gallery ? 0 : 1
}