output agent_subnet_id {
  value                        = module.network.agent_subnet_id
}

output diagnostics_storage_account {
  value                        = azurerm_storage_account.diagnostics.name
}
output diagnostics_storage_sas {
  sensitive                    = true
  value                        = data.azurerm_storage_account_sas.diagnostics.sas
}

output resource_group_name {
  value                        = azurerm_resource_group.rg.name
}
output resource_suffix {
  value                        = local.suffix
}
output self_hosted_linux_vm_ids {
  value                        = var.use_self_hosted ? module.self_hosted_agents.0.linux_vm_ids : null
}
output self_hosted_windows_vm_ids {
  value                        = var.use_self_hosted ? module.self_hosted_agents.0.windows_vm_ids : null
}

output user_name {
  value                        = var.user_name
}
output user_password {
  sensitive                    = true
  value                        = local.password
}

output virtual_network_id {
  value                        = module.network.virtual_network_id
}