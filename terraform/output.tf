output diagnostics_storage_account {
  value                        = azurerm_storage_account.diagnostics.name
}
output diagnostics_storage_sas {
  sensitive                    = true
  value                        = data.azurerm_storage_account_sas.diagnostics.sas
}

output linux_os_image_id {
  value                        = local.linux_image_id
}

output log_analytics_workspace_id {
  value                        = local.log_analytics_workspace_id
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

output service_principal_application_id {
  value                        = var.create_contributor_service_principal ? module.service_principal.0.application_id : null
}
output service_principal_object_id {
  value                        = var.create_contributor_service_principal ? module.service_principal.0.object_id : null
}
output service_principal_principal_id {
  value                        = var.create_contributor_service_principal ? module.service_principal.0.principal_id : null
}
output service_principal_secret {
  sensitive                    = true
  value                        = var.create_contributor_service_principal ? module.service_principal.0.secret : null
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

output windows_os_image_id {
  value                        = local.windows_image_id
}