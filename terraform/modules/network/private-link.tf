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
resource azurerm_private_dns_zone vault {
  name                         = "privatelink.vaultcore.azure.net"
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
resource azurerm_private_dns_zone_virtual_network_link vault {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-vault"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.vault.name
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id

  tags                         = var.tags
}

resource azurerm_subnet private_endpoint_subnet {
  name                         = "PrivateEndpointSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],4,5)]
  private_endpoint_network_policies_enabled = true

  # FIX: Resource is in Updating state and the last operation that updated/is updating the resource is PutSubnetOperation
  provisioner local-exec {
    command                    = "az resource wait --created --ids ${self.id}"
  }

  depends_on                   = [
    azurerm_network_security_group.default
  ]
}
resource time_sleep private_endpoint_nsg_association {
  depends_on                   = [azurerm_subnet.private_endpoint_subnet]
  create_duration              = "1s"
}
data azurerm_subnet private_endpoint_subnet {
  name                          = azurerm_subnet.private_endpoint_subnet.name
  resource_group_name           = azurerm_subnet.private_endpoint_subnet.resource_group_name
  virtual_network_name          = azurerm_subnet.private_endpoint_subnet.virtual_network_name

  depends_on                   = [
    time_sleep.private_endpoint_nsg_association
  ]
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

resource azurerm_monitor_private_link_scope monitor {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-ampls"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = var.tags
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

  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.subnet_id}"
  }

  tags                         = var.tags
  count                        = var.deploy_firewall ? 1 : 0
  depends_on                   = [
    azurerm_private_dns_zone_virtual_network_link.monitor,
    azurerm_private_dns_zone_virtual_network_link.oms,
    azurerm_private_dns_zone_virtual_network_link.ods,
    azurerm_private_dns_zone_virtual_network_link.agentsvc,
    azurerm_private_dns_zone_virtual_network_link.blob,
    null_resource.private_endpoint_nsg_association,
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