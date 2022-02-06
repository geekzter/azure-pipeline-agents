resource azurerm_nat_gateway egress {
  name                         = "${azurerm_virtual_network.packer.name}-natgw"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  sku_name                     = "Standard"

  tags                         = var.tags

  count                        = var.use_remote_gateway ? 0 : 1
}

resource azurerm_public_ip nat_egress {
  name                         = "${azurerm_nat_gateway.egress.0.name}-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.use_remote_gateway ? 0 : 1
}

resource azurerm_nat_gateway_public_ip_association egress {
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id
  public_ip_address_id         = azurerm_public_ip.nat_egress.0.id

  count                        = var.use_remote_gateway ? 0 : 1
}

resource azurerm_subnet_nat_gateway_association packer {
  subnet_id                    = azurerm_subnet.packer.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [azurerm_nat_gateway_public_ip_association.egress]

  count                        = var.use_remote_gateway ? 0 : 1
}