resource azurerm_subnet packer {
  name                         = "Packer"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],4,12)]
}
resource azurerm_network_security_group packer_nsg {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-packer-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = var.tags
}
resource azurerm_network_security_rule packer_ssh {
  name                         = "AllowSSH"
  priority                     = 201
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.packer_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.packer_nsg.name
}
resource azurerm_network_security_rule packer_rdp {
  name                         = "AllowWinRM"
  priority                     = 202
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "5986"
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.packer_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.packer_nsg.name
}
resource azurerm_subnet_network_security_group_association packer {
  subnet_id                    = azurerm_subnet.packer.id
  network_security_group_id    = azurerm_network_security_group.packer_nsg.id
}