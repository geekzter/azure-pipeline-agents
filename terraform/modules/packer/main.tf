resource azurerm_resource_group peer_rg {
  name                         = terraform.workspace == "default" ? "pipeline-images-network-${var.suffix}" : "pipeline-${terraform.workspace}-images-network-${var.suffix}"
  location                     = var.location
  tags                         = var.tags
}