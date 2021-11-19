resource azurerm_private_dns_zone monitor {
  name                         = "privatelink.monitor.azure.com"
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_private_dns_zone oms {
  name                         = "privatelink.oms.opinsights.azure.com"
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_private_dns_zone ods {
  name                         = "privatelink.ods.opinsights.azure.com"
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_private_dns_zone agentsvc {
  name                         = "privatelink.agentsvc.azure-automation.net"
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_private_dns_zone blob {
  name                         = "privatelink.blob.core.windows.net"
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_private_dns_zone_virtual_network_link monitor {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-monitor"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.monitor.0.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_private_dns_zone_virtual_network_link oms {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-oms"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.oms.0.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_private_dns_zone_virtual_network_link ods {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-ods"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.ods.0.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_private_dns_zone_virtual_network_link agentsvc {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-agentsvc"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.agentsvc.0.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_private_dns_zone_virtual_network_link blob {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-blob"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.blob.0.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_subnet private_endpoint_subnet {
  name                         = "PrivateEndpointSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],3,3)]
  enforce_private_link_endpoint_network_policies = true

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_monitor_private_link_scope monitor {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-ampls"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_monitor_private_link_scoped_service log_analytics {
  name                         = "${azurerm_monitor_private_link_scope.monitor.0.name}-log-analytics"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  scope_name                   = azurerm_monitor_private_link_scope.monitor.0.name
  linked_resource_id           = var.log_analytics_workspace_resource_id

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_private_endpoint diag_blob_storage_endpoint {
  name                         = "${azurerm_monitor_private_link_scope.monitor.0.name}-endpoint"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  location                     = azurerm_virtual_network.pipeline_network.location
  
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.0.id

  private_dns_zone_group {
    name                       = "azure-monitor-zones"
    private_dns_zone_ids       = [
      azurerm_private_dns_zone.monitor.0.id,
      azurerm_private_dns_zone.oms.0.id,
      azurerm_private_dns_zone.ods.0.id,
      azurerm_private_dns_zone.agentsvc.0.id,
      azurerm_private_dns_zone.blob.0.id,
    ]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_monitor_private_link_scope.monitor.0.name}-endpoint-connection"
    private_connection_resource_id = azurerm_monitor_private_link_scope.monitor.0.id
    subresource_names          = ["azuremonitor"]
  }

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
  depends_on                   = [
    azurerm_private_dns_zone_virtual_network_link.monitor,
    azurerm_private_dns_zone_virtual_network_link.oms,
    azurerm_private_dns_zone_virtual_network_link.ods,
    azurerm_private_dns_zone_virtual_network_link.agentsvc,
    azurerm_private_dns_zone_virtual_network_link.blob,
  ]
}