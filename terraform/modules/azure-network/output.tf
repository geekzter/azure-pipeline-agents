output agent_address_range {
  value                        = azurerm_subnet.self_hosted_agents.address_prefixes[0]
}

output private_endpoint_subnet_id {
  value                        = azurerm_subnet.private_endpoint_subnet.id
  depends_on                   = [
    time_sleep.wait_for_private_endpoint_subnet
  ]
}
output azurerm_private_dns_zone_blob_id {
  value                        = azurerm_private_dns_zone.blob.id
}
output azurerm_private_dns_zone_blob_name {
  value                        = azurerm_private_dns_zone.blob.name
}
output azurerm_private_dns_zone_file_id {
  value                        = azurerm_private_dns_zone.file.id
}
output azurerm_private_dns_zone_file_name {
  value                        = azurerm_private_dns_zone.file.name
}
output azurerm_private_dns_zone_vault_id {
  value                        = azurerm_private_dns_zone.vault.id
}
output azurerm_private_dns_zone_vault_name {
  value                        = azurerm_private_dns_zone.vault.name
}

output gateway_ip_address {
  value                        = var.deploy_firewall ? azurerm_firewall.firewall.0.ip_configuration.0.private_ip_address : null
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
locals {
  # HACK depend on subnet operations to complete before exposing virtual_network_id
  depend_on_subnet_id          = coalesce(
    try(azurerm_subnet_network_security_group_association.bastion_nsg.0.subnet_id,null),
    try(azurerm_private_endpoint.diag_blob_storage_endpoint.0.subnet_id,null),
    try(azurerm_subnet_network_security_group_association.private_endpoint_subnet.subnet_id,null),
    azurerm_subnet_network_security_group_association.scale_set_agents.subnet_id,
    azurerm_subnet_network_security_group_association.self_hosted_agents.subnet_id,
  )
}
output virtual_network_id {
  value                        = join("/",slice(split("/",local.depend_on_subnet_id),0,9))
}