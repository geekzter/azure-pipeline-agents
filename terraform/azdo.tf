locals {
  azdo_org_url                 = "https://dev.azure.com/${var.azdo_org}"
  azdo_project_id              = length(local.azdo_project_ids) > 0 ? local.azdo_project_ids[0] : null
  azdo_project_ids             = [for project in data.azuredevops_project.projects : project.id]
  azdo_project_name            = length(var.azdo_project_names) > 0 ? var.azdo_project_names[0] : null
  azdo_project_url             = local.create_azdo_resources ? "https://dev.azure.com/${var.azdo_org}/${local.azdo_project_id}" : null
  azdo_service_connection_id   = local.create_azdo_resources ? (local.create_service_connection ? module.azure_devops_service_connection.0.service_connection_id : var.azdo_service_connection_id) : null

  create_azdo_resources        = var.azdo_org != null && var.azdo_org != "" && length(var.azdo_project_names) > 0
  create_linux_scale_set_pool  = (local.create_azdo_resources && var.deploy_scale_set && var.linux_scale_set_agent_count > 0)
  create_windows_scale_set_pool= (local.create_azdo_resources && var.deploy_scale_set && var.windows_scale_set_agent_count > 0)
  create_service_connection    = !(var.azdo_service_connection_id != null && var.azdo_service_connection_id != "")
}

data azuredevops_project projects {
  name                         = each.value

  for_each                     = toset(var.azdo_project_names)
}