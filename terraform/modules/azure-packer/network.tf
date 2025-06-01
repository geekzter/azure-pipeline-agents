resource azurerm_virtual_network packer {
  name                         = "${azurerm_resource_group.network.name}-network"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.network.name
  address_space                = [var.address_space]

  tags                         = var.tags
}
resource azurerm_subnet packer {
  name                         = "Packer"
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  virtual_network_name         = azurerm_virtual_network.packer.name
  address_prefixes             = [cidrsubnet(tolist(azurerm_virtual_network.packer.address_space)[0],4,12)]
  default_outbound_access_enabled = false
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
  source_address_prefix        = var.agent_address_range
  destination_address_prefixes = azurerm_subnet.packer.address_prefixes
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
  source_address_prefix        = var.agent_address_range
  destination_address_prefixes = azurerm_subnet.packer.address_prefixes
  resource_group_name          = azurerm_network_security_group.packer_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.packer_nsg.name
}
resource azurerm_subnet_network_security_group_association packer {
  subnet_id                    = azurerm_subnet.packer.id
  network_security_group_id    = azurerm_network_security_group.packer_nsg.id
  
  lifecycle {
    ignore_changes             = [
      network_security_group_id # Ignore policy changes
    ]
  }
}

resource azurerm_subnet private_endpoint_subnet {
  name                         = "PrivateEndpointSubnet"
  virtual_network_name         = azurerm_virtual_network.packer.name
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  address_prefixes             = [cidrsubnet(tolist(azurerm_virtual_network.packer.address_space)[0],4,5)]
  default_outbound_access_enabled = false
  private_endpoint_network_policies = "Disabled"

  depends_on                   = [
    azurerm_network_security_group.default
  ]
}

resource azurerm_network_security_group default {
  name                         = "${azurerm_virtual_network.packer.name}-default-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name

  tags                         = var.tags
}

resource azurerm_subnet_network_security_group_association private_endpoint_subnet {
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.id
  network_security_group_id    = azurerm_network_security_group.default.id

  depends_on                   = [
    azurerm_subnet_network_security_group_association.private_endpoint_subnet
  ]

  lifecycle {
    ignore_changes             = [
      network_security_group_id # Ignore policy changes
    ]
  }
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

  depends_on                   = [
    azurerm_subnet_network_security_group_association.private_endpoint_subnet
  ]
}