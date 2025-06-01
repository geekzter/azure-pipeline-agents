locals {
  scale_set_agent_address_prefixes = [cidrsubnet(tolist(azurerm_virtual_network.pipeline_network.address_space)[0],4,8)]  
  self_hosted_agent_address_prefixes = [cidrsubnet(tolist(azurerm_virtual_network.pipeline_network.address_space)[0],4,9)]  
}


resource azurerm_subnet scale_set_agents {
  name                         = "ScaleSetAgents"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = local.scale_set_agent_address_prefixes
  default_outbound_access_enabled = false
  depends_on                   = [
    azurerm_network_security_rule.agent_rdp,
    azurerm_network_security_rule.agent_ssh,
    time_sleep.agent_nsg_destroy_race_condition,
    azurerm_route_table.fw_route_table,
    time_sleep.fw_route_table_destroy_race_condition
  ]
}

resource azurerm_subnet self_hosted_agents {
  name                         = "SelfHostedAgents"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = local.self_hosted_agent_address_prefixes
  default_outbound_access_enabled = false
  depends_on                   = [
    azurerm_network_security_rule.agent_rdp,
    azurerm_network_security_rule.agent_ssh,
    time_sleep.agent_nsg_destroy_race_condition,
    azurerm_route_table.fw_route_table,
    time_sleep.fw_route_table_destroy_race_condition
  ]
}

resource azurerm_network_security_group agent_nsg {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-agent-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = var.tags
}
# FIX: Error: deleting Network Security Group "azure-pipelines-agents-ci-99999b-westeurope-network-nsg" (Resource Group "azure-pipelines-agents-ci-99999b"): network.SecurityGroupsClient#Delete: Failure sending request: StatusCode=400 -- Original Error: Code="InUseNetworkSecurityGroupCannotBeDeleted" Message="Network security group /subscriptions/84c1a2c7-585a-4753-ad28-97f69618cf12/resourceGroups/azure-pipelines-agents-ci-99999b/providers/Microsoft.Network/networkSecurityGroups/azure-pipelines-agents-ci-99999b-westeurope-network-nsg cannot be deleted because it is in use by the following resources: /subscriptions/84c1a2c7-585a-4753-ad28-97f69618cf12/resourceGroups/azure-pipelines-agents-ci-99999b/providers/Microsoft.Network/virtualNetworks/azure-pipelines-agents-ci-99999b-westeurope-network/subnets/SelfHostedAgents. In order to delete the Network security group, remove the association with the resource(s). To learn how to do this, see aka.ms/deletensg." Details=[]
resource time_sleep agent_nsg_destroy_race_condition {
  depends_on                   = [azurerm_network_security_group.agent_nsg]
  destroy_duration             = "${var.destroy_wait_minutes}m"
}

resource azurerm_network_security_rule agent_ssh {
  name                         = "AllowSSH"
  priority                     = 201
  direction                    = "Inbound"
  access                       = var.enable_public_access ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefixes = concat(local.scale_set_agent_address_prefixes,local.self_hosted_agent_address_prefixes)
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
resource azurerm_network_security_rule agent_rdp {
  name                         = "AllowRDP"
  priority                     = 202
  direction                    = "Inbound"
  access                       = var.enable_public_access ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "3389"
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefixes = concat(local.scale_set_agent_address_prefixes,local.self_hosted_agent_address_prefixes)
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}

resource azurerm_subnet_network_security_group_association scale_set_agents {
  subnet_id                    = azurerm_subnet.scale_set_agents.id
  network_security_group_id    = azurerm_network_security_group.agent_nsg.id

  lifecycle {
    ignore_changes             = [
      network_security_group_id # Ignore policy changes
    ]
  }
}

resource azurerm_subnet_network_security_group_association self_hosted_agents {
  subnet_id                    = azurerm_subnet.self_hosted_agents.id
  network_security_group_id    = azurerm_network_security_group.agent_nsg.id

  depends_on                   = [
    azurerm_subnet_network_security_group_association.scale_set_agents
  ]
  
  lifecycle {
    ignore_changes             = [
      network_security_group_id # Ignore policy changes
    ]
  }
}