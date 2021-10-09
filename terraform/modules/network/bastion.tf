resource azurerm_subnet bastion_subnet {
  name                         = "AzureBastionSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],3,2)]

  count                        = var.deploy_bastion ? 1 : 0
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

  count                        = var.deploy_bastion ? 1 : 0
} 

resource azurerm_bastion_host bastion {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-bastion"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  ip_configuration {
    name                       = "configuration"
    subnet_id                  = azurerm_subnet.bastion_subnet.0.id
    public_ip_address_id       = azurerm_public_ip.bastion_ip.0.id
  }

  tags                         = var.tags

  count                        = var.deploy_bastion ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting bastion {
  name                         = "${azurerm_bastion_host.bastion.0.name}-logs"
  target_resource_id           = azurerm_bastion_host.bastion.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  log {
    category                   = "BastionAuditLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  count                        = var.deploy_bastion ? 1 : 0
} 