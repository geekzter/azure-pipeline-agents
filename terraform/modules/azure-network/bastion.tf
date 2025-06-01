locals {
  all_bastion_tags             = merge(var.bastion_tags, var.tags)
}

resource azurerm_subnet bastion_subnet {
  name                         = "AzureBastionSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(tolist(azurerm_virtual_network.pipeline_network.address_space)[0],4,1)]
  default_outbound_access_enabled = false
}

# https://docs.microsoft.com/en-us/azure/bastion/bastion-nsg
resource azurerm_network_security_group bastion_nsg {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-bastion-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = local.all_bastion_tags

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule https_inbound {
  name                         = "AllowHttpsInbound"
  priority                     = 220
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "Internet"
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.bastion_nsg.0.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.0.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule gateway_manager_inbound {
  name                         = "AllowGatewayManagerInbound"
  priority                     = 230
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "GatewayManager"
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.bastion_nsg.0.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.0.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule load_balancer_inbound {
  name                         = "AllowLoadBalancerInbound"
  priority                     = 240
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "AzureLoadBalancer"
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.bastion_nsg.0.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.0.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule bastion_host_communication_inbound {
  name                         = "AllowBastionHostCommunication"
  priority                     = 250
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_ranges      = ["5701","8080"]
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefix   = "VirtualNetwork"
  resource_group_name          = azurerm_network_security_group.bastion_nsg.0.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.0.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule ras_outbound {
  name                         = "AllowSshRdpOutbound"
  priority                     = 200
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_ranges      = ["22","3389"]
  source_address_prefix        = "*"
  destination_address_prefix   = "VirtualNetwork"
  resource_group_name          = azurerm_network_security_group.bastion_nsg.0.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.0.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule azure_outbound {
  name                         = "AllowAzureCloudOutbound"
  priority                     = 210
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "*"
  destination_address_prefix   = "AzureCloud"
  resource_group_name          = azurerm_network_security_group.bastion_nsg.0.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.0.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule bastion_host_communication_oubound {
  name                         = "AllowBastionCommunication"
  priority                     = 220
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_ranges      = ["5701","8080"]
  source_address_prefix        = "VirtualNetwork"
  destination_address_prefix   = "VirtualNetwork"
  resource_group_name          = azurerm_network_security_group.bastion_nsg.0.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.0.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_network_security_rule get_session_oubound {
  name                         = "AllowGetSessionInformation"
  priority                     = 230
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "80"
  source_address_prefix        = "*"
  destination_address_prefix   = "Internet"
  resource_group_name          = azurerm_network_security_group.bastion_nsg.0.resource_group_name
  network_security_group_name  = azurerm_network_security_group.bastion_nsg.0.name

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_subnet_network_security_group_association bastion_nsg {
  subnet_id                    = azurerm_subnet.bastion_subnet.id
  network_security_group_id    = azurerm_network_security_group.bastion_nsg.0.id

  count                        = var.deploy_bastion && length(var.bastion_tags) == 0 ? 1 : 0

  depends_on                   = [
    azurerm_network_security_rule.https_inbound,
    azurerm_network_security_rule.gateway_manager_inbound,
    azurerm_network_security_rule.load_balancer_inbound,
    azurerm_network_security_rule.bastion_host_communication_inbound,
    azurerm_network_security_rule.ras_outbound,
    azurerm_network_security_rule.azure_outbound,
    azurerm_network_security_rule.bastion_host_communication_oubound,
    azurerm_network_security_rule.get_session_oubound,
  ]

  lifecycle {
    ignore_changes             = [
      network_security_group_id # Ignore policy changes
    ]
  }
}
resource azurerm_public_ip bastion_ip {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-bastion-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.deploy_bastion ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting bastion_ip {
  name                         = "${azurerm_public_ip.bastion_ip.0.name}-logs"
  target_resource_id           = azurerm_public_ip.bastion_ip.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  enabled_log {
    category                   = "DDoSProtectionNotifications"
  }
  enabled_log {
    category                   = "DDoSMitigationFlowLogs"
  }
  enabled_log {
    category                   = "DDoSMitigationReports"
  }  

  enabled_metric {
    category                   = "AllMetrics"
  }

  count                        = var.deploy_bastion ? 1 : 0
} 

resource azurerm_bastion_host bastion {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-bastion"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  copy_paste_enabled           = true
  file_copy_enabled            = true
  ip_configuration {
    name                       = "configuration"
    subnet_id                  = azurerm_subnet.bastion_subnet.id
    public_ip_address_id       = azurerm_public_ip.bastion_ip.0.id
  }
  sku                          = "Standard"
  tunneling_enabled            = true

  tags                         = local.all_bastion_tags

  count                        = var.deploy_bastion ? 1 : 0
  depends_on                   = [
    azurerm_subnet_network_security_group_association.bastion_nsg
  ]
}

resource azurerm_monitor_diagnostic_setting bastion {
  name                         = "${azurerm_bastion_host.bastion.0.name}-logs"
  target_resource_id           = azurerm_bastion_host.bastion.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  enabled_log {
    category                   = "BastionAuditLogs"
  }

  count                        = var.deploy_bastion ? 1 : 0
} 