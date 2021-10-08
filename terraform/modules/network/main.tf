locals {
  diagnostics_storage_name     = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-1)
  diagnostics_storage_rg       = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-5)
}

data azurerm_storage_account diagnostics {
  name                         = local.diagnostics_storage_name
  resource_group_name          = local.diagnostics_storage_rg
}

resource azurerm_virtual_network pipeline_network {
  name                         = "${var.resource_group_name}-${var.location}-network"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  address_space                = [var.address_space]

  tags                         = var.tags
}
resource azurerm_monitor_diagnostic_setting pipeline_network {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-logs"
  target_resource_id           = azurerm_virtual_network.pipeline_network.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

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

resource azurerm_subnet scale_set_agents {
  name                         = "ScaleSetAgents"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],2,2)]
}
resource azurerm_subnet self_hosted_agents {
  name                         = "SelfHostedAgents"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],2,3)]
}
resource azurerm_network_security_group agent_nsg {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = var.tags
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
resource azurerm_subnet_network_security_group_association scale_set_agents {
  subnet_id                    = azurerm_subnet.scale_set_agents.id
  network_security_group_id    = azurerm_network_security_group.agent_nsg.id
}
resource azurerm_subnet_network_security_group_association self_hosted_agents {
  subnet_id                    = azurerm_subnet.self_hosted_agents.id
  network_security_group_id    = azurerm_network_security_group.agent_nsg.id
}