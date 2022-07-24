resource azurerm_resource_group network {
  name                         = terraform.workspace == "default" ? "${var.prefix}-images-network-${var.suffix}" : "${var.prefix}-${terraform.workspace}-images-network-${var.suffix}"
  location                     = var.location
  tags                         = var.tags
}

resource azurerm_resource_group build {
  name                         = replace(azurerm_resource_group.network.name,"-network","-build")
  location                     = var.location
  tags                         = var.tags
}

data azurerm_resources build_resources {
  resource_group_name          = azurerm_resource_group.build.name
}