locals {
  diagnostics_storage_name     = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-1)
  diagnostics_storage_rg       = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-5)
}

data azurerm_storage_account diagnostics {
  name                         = local.diagnostics_storage_name
  resource_group_name          = local.diagnostics_storage_rg
}

resource azurerm_virtual_network pipeline_network {
  name                         = "${var.resource_group_name}-network"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  address_space                = [var.address_space]

  tags                         = local.all_bastion_tags
}
resource azurerm_monitor_diagnostic_setting pipeline_network {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-logs"
  target_resource_id           = azurerm_virtual_network.pipeline_network.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  enabled_log {
    category                   = "VMProtectionAlerts"
  }

  enabled_metric {
    category                   = "AllMetrics"
  }
}

resource azurerm_virtual_network_peering agents_to_packer {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-peering"
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  remote_virtual_network_id    = var.peer_virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on                   = [
    azurerm_private_endpoint.diag_blob_storage_endpoint
  ]

  count                        = var.create_packer_infrastructure ? 1 : 0
}

resource azurerm_network_security_group default {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-default-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name

  tags                         = var.tags
}