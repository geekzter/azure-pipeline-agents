resource azurerm_resource_group peer_rg {
  name                         = terraform.workspace == "default" ? "azure-pipelines-images-network-${var.suffix}" : "azure-pipelines-${terraform.workspace}-images-network-${var.suffix}"
  location                     = var.location
  tags                         = var.tags
}