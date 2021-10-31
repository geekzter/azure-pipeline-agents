resource azurerm_nat_gateway egress {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-natgw"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  sku_name                     = "Standard"

  tags                         = var.tags

  count                        = var.deploy_firewall ? 0 : 1
}

resource azurerm_public_ip nat_egress {
  name                         = "${azurerm_nat_gateway.egress.0.name}-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.deploy_firewall ? 0 : 1
}

resource azurerm_monitor_diagnostic_setting nat_egress {
  name                         = "${azurerm_public_ip.nat_egress.0.name}-logs"
  target_resource_id           = azurerm_public_ip.nat_egress.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

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

  count                        = var.deploy_firewall ? 0 : 1
} 

resource azurerm_nat_gateway_public_ip_association egress {
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id
  public_ip_address_id         = azurerm_public_ip.nat_egress.0.id

  count                        = var.deploy_firewall ? 0 : 1
}

resource azurerm_subnet_nat_gateway_association scale_set_agents {
  subnet_id                    = azurerm_subnet.scale_set_agents.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [azurerm_nat_gateway_public_ip_association.egress]

  count                        = var.deploy_firewall ? 0 : 1
}
resource azurerm_subnet_nat_gateway_association self_hosted_agents {
  subnet_id                    = azurerm_subnet.self_hosted_agents.id
  nat_gateway_id               = azurerm_nat_gateway.egress.0.id

  depends_on                   = [azurerm_nat_gateway_public_ip_association.egress]

  count                        = var.deploy_firewall ? 0 : 1
}