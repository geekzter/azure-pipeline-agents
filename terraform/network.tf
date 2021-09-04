resource azurerm_virtual_network pipeline_network {
  name                         = "${azurerm_resource_group.rg.name}-${var.location}-network"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  address_space                = [var.address_space]

  tags                         = local.tags
}
resource azurerm_monitor_diagnostic_setting pipeline_network {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-logs"
  target_resource_id           = azurerm_virtual_network.pipeline_network.id
  log_analytics_workspace_id   = local.log_analytics_workspace_id

  log {
    category                   = "VMProtectionAlerts"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
}

resource azurerm_subnet agent_subnet {
  name                         = "PipelineAgents"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],1,1)]
}
resource azurerm_network_security_group agent_nsg {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = local.tags
}
resource azurerm_network_security_rule ssh {
  name                         = "AllowSSH"
  priority                     = 201
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefix        = "*"
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
resource azurerm_network_security_rule rdp {
  name                         = "AllowRDP"
  priority                     = 202
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "3389"
  source_address_prefix        = "*"
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.agent_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.agent_nsg.name
}
resource azurerm_subnet_network_security_group_association agent_nsg {
  subnet_id                    = azurerm_subnet.agent_subnet.id
  network_security_group_id    = azurerm_network_security_group.agent_nsg.id
}

resource azurerm_subnet bastion_subnet {
  name                         = "AzureBastionSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],3,0)]
}
resource azurerm_public_ip bastion_ip {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-bastion-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = local.tags
}
resource azurerm_monitor_diagnostic_setting bastion_ip {
  name                         = "${azurerm_public_ip.bastion_ip.name}-logs"
  target_resource_id           = azurerm_public_ip.bastion_ip.id
  log_analytics_workspace_id   = local.log_analytics_workspace_id

  log {
    category                   = "DDoSProtectionNotifications"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "DDoSMitigationFlowLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "DDoSMitigationReports"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }  

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
} 
resource azurerm_bastion_host bastion {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-bastion"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  ip_configuration {
    name                       = "configuration"
    subnet_id                  = azurerm_subnet.bastion_subnet.id
    public_ip_address_id       = azurerm_public_ip.bastion_ip.id
  }

  tags                         = local.tags
}
resource azurerm_monitor_diagnostic_setting bastion {
  name                         = "${azurerm_bastion_host.bastion.name}-logs"
  target_resource_id           = azurerm_bastion_host.bastion.id
  log_analytics_workspace_id   = local.log_analytics_workspace_id

  log {
    category                   = "BastionAuditLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
} 

resource azurerm_nat_gateway egress {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-natgw"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  sku_name                     = "Standard"
}
resource azurerm_public_ip egress {
  name                         = "${azurerm_nat_gateway.egress.name}-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"
}
resource azurerm_monitor_diagnostic_setting egress {
  name                         = "${azurerm_public_ip.egress.name}-logs"
  target_resource_id           = azurerm_public_ip.egress.id
  log_analytics_workspace_id   = local.log_analytics_workspace_id

  log {
    category                   = "DDoSProtectionNotifications"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "DDoSMitigationFlowLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "DDoSMitigationReports"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }  

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
} 
resource azurerm_nat_gateway_public_ip_association egress {
  nat_gateway_id               = azurerm_nat_gateway.egress.id
  public_ip_address_id         = azurerm_public_ip.egress.id
}
resource azurerm_subnet_nat_gateway_association agent_subnet {
  subnet_id                    = azurerm_subnet.agent_subnet.id
  nat_gateway_id               = azurerm_nat_gateway.egress.id

  depends_on                   = [azurerm_nat_gateway_public_ip_association.egress]
}