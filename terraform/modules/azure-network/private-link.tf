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
  address_prefixes             = [cidrsubnet(tolist(azurerm_virtual_network.pipeline_network.address_space)[0],4,5)]
  default_outbound_access_enabled = false
  private_endpoint_network_policies = "Disabled"

  provisioner local-exec {
    command                    = "az resource wait --created --ids ${self.id}"
  }
  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.id}"
  }

  depends_on                   = [
    azurerm_network_security_group.default
  ]
}
# FIX: https://github.com/hashicorp/terraform-provider-azurerm/issues/21293
resource time_sleep wait_for_private_endpoint_subnet {
  create_duration              = "180s"

  triggers                     = {
    subnet_id                  = azurerm_subnet.private_endpoint_subnet.id
  }

  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.triggers["subnet_id"]}"
  }

  depends_on                   = [azurerm_subnet.private_endpoint_subnet]
}

resource azurerm_subnet_network_security_group_association private_endpoint_subnet {
  subnet_id                    = azurerm_subnet.private_endpoint_subnet.id
  network_security_group_id    = azurerm_network_security_group.default.id
  
  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.subnet_id}"
  }

  lifecycle {
    ignore_changes             = [
      network_security_group_id # Ignore policy changes
    ]
  }
}

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
      azurerm_private_dns_zone.agentsvc.0.id,
      azurerm_private_dns_zone.blob.id,
      azurerm_private_dns_zone.monitor.0.id,
      azurerm_private_dns_zone.ods.0.id,
      azurerm_private_dns_zone.oms.0.id,
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
    azurerm_private_dns_zone_virtual_network_link.agentsvc,
    azurerm_private_dns_zone_virtual_network_link.blob,
    azurerm_private_dns_zone_virtual_network_link.monitor,
    azurerm_private_dns_zone_virtual_network_link.ods,
    azurerm_private_dns_zone_virtual_network_link.oms,
    azurerm_subnet_network_security_group_association.private_endpoint_subnet
  ]
}
