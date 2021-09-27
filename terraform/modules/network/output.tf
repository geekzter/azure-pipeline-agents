output agent_subnet_id {
  value                        = azurerm_subnet.agent_subnet.id
}
output virtual_network_id {
  value                        = azurerm_virtual_network.pipeline_network.id
}