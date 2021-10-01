output agent_subnet_id {
  value                        = azurerm_subnet.agent_subnet.id
}
output outbound_ip_address {
  value                        = var.use_firewall ? azurerm_public_ip.firewall.0.ip_address : azurerm_public_ip.nat_egress.0.ip_address
}
output virtual_network_id {
  value                        = azurerm_virtual_network.pipeline_network.id
}