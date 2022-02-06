resource azurerm_resource_group peer_rg {
  name                         = "packer-${terraform.workspace}-${var.suffix}"
  location                     = var.location
  tags                         = var.tags
}