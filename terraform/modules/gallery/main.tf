locals {
  pre_existing_gallery         = var.shared_image_gallery_id != null && var.shared_image_gallery_id != ""
  shared_image_gallery_id      = local.pre_existing_gallery ? var.shared_image_gallery_id : azurerm_shared_image_gallery.compute_gallery.0.id
}

resource azurerm_shared_image_gallery compute_gallery {
  name                         = replace("${var.resource_group_name}-gallery","-",".")
  location                     = var.location
  resource_group_name          = var.resource_group_name
  description                  = "https://github.com/geekzter/azure-pipeline-agents (${terraform.workspace})"

  tags                         = var.tags

  count                        = local.pre_existing_gallery ? 0 : 1
}