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

output scale_set_agents_subnet_id {
  value                        = module.network.scale_set_agents_subnet_id
}
output self_hosted_agents_subnet_id {
  value                        = module.network.self_hosted_agents_subnet_id
}

output self_hosted_vm_id {
  value                        = concat(
    [for vm in module.self_hosted_linux_agents   : vm.vm_id],
    [for vm in module.self_hosted_windows_agents : vm.vm_id]
  )
}

output self_hosted_linux_cloud_config {
  sensitive                    = true
  value                        = var.deploy_self_hosted_vms && var.linux_self_hosted_agent_count > 0 ? module.self_hosted_linux_agents.0.cloud_config : null
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