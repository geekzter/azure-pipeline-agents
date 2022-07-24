locals {
  scale_set_agent_address_prefixes = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],4,8)]  
  self_hosted_agent_address_prefixes = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],4,9)]  
}


resource azurerm_subnet scale_set_agents {
  name                         = "ScaleSetAgents"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = local.scale_set_agent_address_prefixes
  depends_on                   = [
    azurerm_network_security_rule.agent_rdp,
    azurerm_network_security_rule.agent_ssh,
    time_sleep.agent_nsg_destroy_race_condition,
    azurerm_route_table.fw_route_table,
    time_sleep.fw_route_table_destroy_race_condition
  ]
}
resource time_sleep scale_set_nsg_association {
  depends_on                   = [azurerm_subnet.scale_set_agents]
  create_duration              = "1s"
}
data azurerm_subnet scale_set_agents {
  name                         = azurerm_subnet.scale_set_agents.name
  resource_group_name          = azurerm_subnet.scale_set_agents.resource_group_name
  virtual_network_name         = azurerm_subnet.scale_set_agents.virtual_network_name

  depends_on                   = [
    time_sleep.scale_set_nsg_association
  ]
}
resource azurerm_subnet self_hosted_agents {
  name                         = "SelfHostedAgents"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = local.self_hosted_agent_address_prefixes
  depends_on                   = [
    azurerm_network_security_rule.agent_rdp,
    azurerm_network_security_rule.agent_ssh,
    time_sleep.agent_nsg_destroy_race_condition,
    azurerm_route_table.fw_route_table,
    time_sleep.fw_route_table_destroy_race_condition
  ]
}
resource time_sleep self_hosted_nsg_association {
  depends_on                   = [azurerm_subnet.scale_set_agents]
  create_duration              = "1s"
}
data azurerm_subnet self_hosted_agents {
  name                         = azurerm_subnet.self_hosted_agents.name
  resource_group_name          = azurerm_subnet.self_hosted_agents.resource_group_name
  virtual_network_name         = azurerm_subnet.self_hosted_agents.virtual_network_name

  depends_on                   = [
    time_sleep.self_hosted_nsg_association
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

# Address race condition where policy assigned NSG before we can assign our own
# Let's wait for any updates to happen, then overwrite our own
# This removes the need to use azurerm_subnet_network_security_group_association
resource null_resource scale_set_nsg_association {
  triggers                     = {
    nsg                        = coalesce(data.azurerm_subnet.scale_set_agents.network_security_group_id,azurerm_network_security_group.agent_nsg.id)
  }

  provisioner local-exec {
    # command                    = "az network vnet subnet update --ids ${azurerm_subnet.scale_set_agents.id} --nsg ${azurerm_network_security_group.agent_nsg.id} --query 'networkSecurityGroup'"
    command                    = "${path.root}/../scripts/create_nsg_assignment.ps1 -SubnetId ${azurerm_subnet.scale_set_agents.id} -NsgId ${azurerm_network_security_group.agent_nsg.id}"
    interpreter                = ["pwsh","-nop","-command"]
  }  
}
# resource azurerm_subnet_network_security_group_association scale_set_agents {
#   subnet_id                    = azurerm_subnet.scale_set_agents.id
#   network_security_group_id    = azurerm_network_security_group.agent_nsg.id

#   depends_on                   = [
#     null_resource.scale_set_nsg_association
#   ]
# }
# Address race condition where policy assigned NSG before we can assign our own
# Let's wait for any updates to happen, then overwrite our own
# This removes the need to use azurerm_subnet_network_security_group_association
resource null_resource self_hosted_nsg_association {
  triggers                     = {
    nsg                        = coalesce(data.azurerm_subnet.self_hosted_agents.network_security_group_id,azurerm_network_security_group.agent_nsg.id)
  }

  provisioner local-exec {
    # command                    = "az network vnet subnet update --ids ${azurerm_subnet.self_hosted_agents.id} --nsg ${azurerm_network_security_group.agent_nsg.id} --query 'networkSecurityGroup'"
    command                    = "${path.root}/../scripts/create_nsg_assignment.ps1 -SubnetId ${azurerm_subnet.self_hosted_agents.id} -NsgId ${azurerm_network_security_group.agent_nsg.id}"
    interpreter                = ["pwsh","-nop","-command"]
  }  
}
# resource azurerm_subnet_network_security_group_association self_hosted_agents {
#   subnet_id                    = azurerm_subnet.self_hosted_agents.id
#   network_security_group_id    = azurerm_network_security_group.agent_nsg.id

#   depends_on                   = [
#     null_resource.self_hosted_nsg_association
#   ]
# }