resource azurerm_nat_gateway egress {
  name                         = "${azurerm_virtual_network.packer.name}-natgw"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  sku_name                     = "Standard"

  tags                         = var.tags

  count                        = var.deploy_nat_gateway ? 1 : 0
}

resource azurerm_public_ip nat_egress {
  name                         = "${azurerm_nat_gateway.egress.0.name}-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.deploy_nat_gateway ? 1 : 0
}

resource azurerm_nat_gateway_public_ip_association egress {
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id
  public_ip_address_id         = azurerm_public_ip.nat_egress.0.id

  count                        = var.deploy_nat_gateway ? 1 : 0
}

resource azurerm_subnet_nat_gateway_association packer {
  subnet_id                    = azurerm_subnet.packer.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [azurerm_nat_gateway_public_ip_association.egress]

  count                        = var.deploy_nat_gateway ? 1 : 0
}

resource azurerm_subnet_nat_gateway_association private_endpoint_subnet {
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [azurerm_nat_gateway_public_ip_association.egress]

  count                        = var.deploy_nat_gateway ? 1 : 0
}

resource azurerm_route_table route_table {
  name                         = "${azurerm_virtual_network.packer.name}-routes"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.network.name

  route {
    name                       = "VnetLocal"
    address_prefix             = var.address_space
    next_hop_type              = "VnetLocal"
  }
  route {
    name                       = "InternetViaFW"
    address_prefix             = "0.0.0.0/0"
    next_hop_type              = "VirtualAppliance"
    next_hop_in_ip_address     = var.gateway_ip_address
  }
  tags                         = var.tags

  count                        = var.deploy_nat_gateway ? 0 : 1
}
resource azurerm_subnet_route_table_association packer {
  subnet_id                    = azurerm_subnet.packer.id
  route_table_id               = azurerm_route_table.route_table.0.id

  count                        = var.deploy_nat_gateway ? 0 : 1
}