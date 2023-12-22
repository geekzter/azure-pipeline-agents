output agent_diagnostics_file_share_url {
  value                        = var.deploy_files_share ? azurerm_storage_share.diagnostics_smb_share.0.url : null
}
output agent_identity_name {
  value                        = azurerm_user_assigned_identity.agents.name
}
output agent_identity_client_id {
  value                        = azurerm_user_assigned_identity.agents.client_id
}
output agent_identity_object_id {
  value                        = azurerm_user_assigned_identity.agents.principal_id
}

output azdo_linux_scale_set_pool_id {
  value                        = local.create_linux_scale_set_pool ? module.linux_scale_set_pool.0.id : null
}
output azdo_linux_scale_set_pool_name {
  value                        = local.create_linux_scale_set_pool ? module.linux_scale_set_pool.0.name : null
}
output azdo_linux_scale_set_pool_url {
  value                        = local.create_linux_scale_set_pool ? "${local.azdo_org_url}/_settings/agentpools?poolId=${module.linux_scale_set_pool.0.id}&view=jobs": null
}
output azdo_service_connection_id {
  value                        = local.azdo_service_connection_id
}
output azdo_service_connection_url {
  value                        = local.create_azdo_resources ? "${data.azuredevops_client_config.current.organization_url}/${local.azdo_project_id}/_settings/adminservices?resourceId=${local.azdo_service_connection_id}" : null
}
output azdo_windows_scale_set_pool_id {
  value                        = local.create_windows_scale_set_pool ? module.windows_scale_set_pool.0.id : null
}
output azdo_windows_scale_set_pool_name {
  value                        = local.create_windows_scale_set_pool ? module.windows_scale_set_pool.0.name : null
}
output azdo_windows_scale_set_pool_url {
  value                        = local.create_windows_scale_set_pool ? "${local.azdo_org_url}/_settings/agentpools?poolId=${module.windows_scale_set_pool.0.id}&view=jobs": null
}

output build_network_resource_group_id {
  value                        = var.create_packer_infrastructure ? module.packer.0.network_resource_group_id : null
}
output build_resource_group_id {
  value                        = var.create_packer_infrastructure ? module.packer.0.build_resource_group_id : null
}
output build_resource_ids {
  value                        = var.create_packer_infrastructure ? module.packer.0.build_resource_ids : null
}

output diagnostics_storage_account {
  value                        = azurerm_storage_account.diagnostics.name
}
output diagnostics_storage_sas {
  sensitive                    = true
  value                        = data.azurerm_storage_account_sas.diagnostics.sas
}

output environment_variables {
  value                        = local.environment_variables
}

output linux_os_image_id {
  value                        = local.linux_image_id
}
output linux_virtual_machine_scale_set_id {
  value                        = var.deploy_scale_set && var.linux_scale_set_agent_count > 0 ? module.scale_set_linux_agents.0.virtual_machine_scale_set_id : null
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
output scale_set_linux_cloud_config {
  sensitive                    = true
  value                        = var.deploy_scale_set && var.linux_scale_set_agent_count > 0 ? module.scale_set_linux_agents.0.cloud_config : null
}
output scale_set_windows_host_configuration_script {
  sensitive                    = true
  value                        = var.deploy_scale_set && var.windows_scale_set_agent_count > 0 ? module.scale_set_windows_agents.0.host_configuration_script : null
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

output ssh_private_key_id {
  value                        = azurerm_key_vault_secret.ssh_private_key.id
}
output ssh_public_key_id {
  value                        = azurerm_ssh_public_key.ssh_key.id
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
output windows_virtual_machine_scale_set_id {
  value                        = var.deploy_scale_set && var.windows_scale_set_agent_count > 0 ? module.scale_set_windows_agents.0.virtual_machine_scale_set_id : null
}