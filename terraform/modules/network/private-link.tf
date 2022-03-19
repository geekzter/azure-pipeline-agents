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
}
resource azurerm_private_dns_zone file {
  name                         = "privatelink.file.core.windows.net"
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
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
  private_dns_zone_name        = azurerm_private_dns_zone.blob.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
}
resource azurerm_private_dns_zone_virtual_network_link file {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-file"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.file.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
}

resource azurerm_subnet private_endpoint_subnet {
  name                         = "PrivateEndpointSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],4,5)]
  enforce_private_link_endpoint_network_policies = true
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
  
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.id

  private_dns_zone_group {
    name                       = "azure-monitor-zones"
    private_dns_zone_ids       = [
      azurerm_private_dns_zone.monitor.0.id,
      azurerm_private_dns_zone.oms.0.id,
      azurerm_private_dns_zone.ods.0.id,
      azurerm_private_dns_zone.agentsvc.0.id,
      azurerm_private_dns_zone.blob.id,
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
# FIX: Error: deleting Private DNS Zone Group "azure-monitor-zones" (Private Endpoint "azure-pipelines-agents-ci-99999b-westeurope-network-ampls-endpoint" / Resource Group "azure-pipelines-agents-ci-99999b"): network.PrivateDNSZoneGroupsClient#Delete: Failure sending request: StatusCode=0 -- Original Error: autorest/azure: Service returned an error. Status=<nil> Code="AnotherOperationInProgress" Message="Another operation on this or dependent resource is in progress. To retrieve status of the operation use uri: https://management.azure.com/subscriptions/84c1a2c7-585a-4753-ad28-97f69618cf12/providers/Microsoft.Network/locations/westeurope/operations/e2bff2ad-cfad-4bfa-971f-3cb2a34df13c?api-version=2019-02-01." Details=[]
resource time_sleep diag_blob_storage_endpoint_destroy_race_condition {
  depends_on                   = [azurerm_private_endpoint.diag_blob_storage_endpoint]
  destroy_duration             = "${var.destroy_wait_minutes}m"
}

resource azurerm_private_dns_a_record packer_storage {
  name                         = var.packer_storage_account_name
  zone_name                    = azurerm_private_dns_zone.blob.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  ttl                          = 300
  records                      = [var.packer_storage_ip_address]
}