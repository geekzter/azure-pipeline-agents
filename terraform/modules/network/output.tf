output private_endpoint_subnet_id {
  value                        = azurerm_subnet.private_endpoint_subnet.id
}
output azurerm_private_dns_zone_blob_id {
  value                        = azurerm_private_dns_zone.blob.id
}
output azurerm_private_dns_zone_blob_name {
  value                        = azurerm_private_dns_zone.blob.name
}

output scale_set_agents_subnet_id {
  value                        = azurerm_subnet.scale_set_agents.id
}
output self_hosted_agents_subnet_id {
  value                        = azurerm_subnet.self_hosted_agents.id
}
output outbound_ip_address {
  value                        = var.deploy_firewall ? azurerm_public_ip.firewall.0.ip_address : azurerm_public_ip.nat_egress.0.ip_address
}
output virtual_network_id {
  value                        = azurerm_virtual_network.pipeline_network.id
}