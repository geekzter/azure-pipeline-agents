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
}

resource azurerm_subnet private_endpoint_subnet {
  name                         = "PrivateEndpointSubnet"
  virtual_network_name         = azurerm_virtual_network.packer.name
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.packer.address_space[0],4,5)]
  private_endpoint_network_policies_enabled = true

  depends_on                   = [
    azurerm_network_security_group.default
  ]
}
resource time_sleep private_endpoint_nsg_association {
  depends_on                   = [azurerm_subnet.private_endpoint_subnet]
  create_duration              = "1s"
}
data azurerm_subnet private_endpoint_subnet {
  name                         = azurerm_subnet.private_endpoint_subnet.name
  resource_group_name          = azurerm_subnet.private_endpoint_subnet.resource_group_name
  virtual_network_name         = azurerm_subnet.private_endpoint_subnet.virtual_network_name

  depends_on                   = [
    time_sleep.private_endpoint_nsg_association
  ]
}
resource azurerm_network_security_group default {
  name                         = "${azurerm_virtual_network.packer.name}-default-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.packer.resource_group_name

  tags                         = var.tags
}
# Address race condition where policy assigned NSG before we can assign our own
# Let's wait for any updates to happen, then overwrite our own
# This removes the need to use azurerm_subnet_network_security_group_association
resource null_resource private_endpoint_nsg_association {
  triggers                     = {
    nsg                        = coalesce(data.azurerm_subnet.private_endpoint_subnet.network_security_group_id,azurerm_network_security_group.default.id)
  }

  provisioner local-exec {
    # command                    = "az network vnet subnet update --ids ${azurerm_subnet.private_endpoint_subnet.id} --nsg ${azurerm_network_security_group.default.id} --query 'networkSecurityGroup'"
    command                    = "${path.root}/../scripts/create_nsg_assignment.ps1 -SubnetId ${azurerm_subnet.private_endpoint_subnet.id} -NsgId ${azurerm_network_security_group.default.id}"
    interpreter                = ["pwsh","-nop","-command"]
  }  
}
# resource azurerm_subnet_network_security_group_association private_endpoint_subnet {
#   subnet_id                    = azurerm_subnet.private_endpoint_subnet.id
#   network_security_group_id    = azurerm_network_security_group.default.id

#   depends_on                   = [
#     null_resource.private_endpoint_nsg_association
#   ]
# }

# FIX: Resource is in Updating state and the last operation that updated/is updating the resource is PutSubnetOperation"
resource time_sleep private_endpoint_subnet {
  depends_on                   = [
    # azurerm_subnet_network_security_group_association.private_endpoint_subnet,
    null_resource.private_endpoint_nsg_association
  ]
  create_duration              = "2m"
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