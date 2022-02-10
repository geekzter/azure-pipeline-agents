resource azurerm_virtual_network packer {
  name                         = "${azurerm_resource_group.network.name}-${var.location}-network"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.network.name
  address_space                = [var.address_space]

  tags                         = var.tags
}
resource azurerm_subnet packer {
  name                         = "Packer"
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  virtual_network_name         = azurerm_virtual_network.packer.name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.packer.address_space[0],4,12)]
}
resource azurerm_network_security_group packer_nsg {
  name                         = "${azurerm_virtual_network.packer.name}-packer-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name

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
  source_address_prefix        = "VirtualNetwork"
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
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.packer_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.packer_nsg.name
}
resource azurerm_subnet_network_security_group_association packer {
  subnet_id                    = azurerm_subnet.packer.id
  network_security_group_id    = azurerm_network_security_group.packer_nsg.id
}

resource azurerm_subnet private_endpoint_subnet {
  name                         = "PrivateEndpointSubnet"
  virtual_network_name         = azurerm_virtual_network.packer.name
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.packer.address_space[0],4,5)]
  enforce_private_link_endpoint_network_policies = true
}

resource azurerm_virtual_network_peering packer_to_agents {
  name                         = "${azurerm_virtual_network.packer.name}-peering"
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  virtual_network_name         = azurerm_virtual_network.packer.name
  remote_virtual_network_id    = var.peer_virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}