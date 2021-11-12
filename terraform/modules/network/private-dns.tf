resource azurerm_private_dns_zone zone {
  name                         = "privatelink.blob.core.windows.net"
  resource_group_name          = var.resource_group_name

  tags                         = var.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_private_dns_zone_virtual_network_link hub_link {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-dns-blob"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  private_dns_zone_name        = azurerm_private_dns_zone.zone.0.name
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
}

# TODO: https://github.com/hashicorp/terraform-provider-azurerm/pull/14119
# resource azurerm_monitor_private_link_scoped_service log_analytics {
#   name                         = "${azurerm_monitor_private_link_scope.monitor}-log-analytics"
#   resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
#   scope_name                   = azurerm_monitor_private_link_scope.test.monitor
#   linked_resource_id           = var.log_analytics_workspace_resource_id
# }