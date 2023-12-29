data external azdo_token {
  program                      = [
    "az", "account", "get-access-token", 
    "--resource", "499b84ac-1321-427f-aa17-267ca6975798", # Azure DevOps
    "--query","{accessToken:accessToken}",
    "-o","json"
  ]
}

data azuredevops_client_config current {}

data azuredevops_project projects {
  name                         = each.value

  for_each                     = toset(var.azdo_project_names)
}

locals {
  azdo_deployment_group_name   = var.azdo_self_hosted_pool_type == "DeploymentGroup" ? var.azdo_self_hosted_pool_name : null
  azdo_environment_id          = var.azdo_self_hosted_pool_type == "Environment" ? module.azdo_environment.0.id : null
  azdo_environment_name        = var.azdo_self_hosted_pool_type == "Environment" ? module.azdo_environment.0.name : null
  azdo_org_url                 = replace(var.azdo_org_url,"/\\/$/","")
  azdo_org                     = coalesce(values(regex("https://dev.azure.com/(?P<org1>[^/]+)|https://(?P<org2>[^/]+).visualstudio.com","https://ericvan.visualstudio.com"))...)
  azdo_pools                   = merge(
    can(module.linux_scale_set_pool.0.id) ? {
      "linuxScaleSetAgents" = {
        os  = "Linux"
        pool = module.linux_scale_set_pool.0.name
      }
    } : {},
    can(module.windows_scale_set_pool.0.id) ? {
      "windowsScaleSetAgents" = {
        os  = "Windows_NT"
        pool = module.windows_scale_set_pool.0.name
      }
    } : {},
    can(module.self_hosted_pool.0.id) && can(module.self_hosted_linux_agents.0.vm_id) ? {
      "linuxSelfHostedAgents" = {
        os  = "Linux"
        pool = module.self_hosted_pool.0.name
      }
    } : {},
    can(module.self_hosted_pool.0.id) && can(module.self_hosted_windows_agents.0.vm_id) ? {
      "windowsSelfHostedAgents" = {
        os  = "Windows_NT"
        pool = module.self_hosted_pool.0.name
      }
    } : {},
  )
  azdo_project_id              = local.azdo_project_name != null ? [for project in data.azuredevops_project.projects : project.id if project.name == local.azdo_project_name][0] : null
  azdo_project_ids             = [for project in data.azuredevops_project.projects : project.id]
  azdo_project_name            = length(var.azdo_project_names) > 0 ? var.azdo_project_names[0] : null
  azdo_project_url             = local.create_azdo_resources ? "https://dev.azure.com/${local.azdo_org}/${local.azdo_project_id}" : null
  azdo_self_hosted_pool_name   = local.create_azdo_resources && var.deploy_azdo_self_hosted_vm_agents && var.azdo_self_hosted_pool_type == "AgentPool" ? module.self_hosted_pool.0.name : null
  azdo_service_connection_id   = local.create_azdo_resources ? (local.create_azdo_service_connection ? module.azure_devops_service_connection.0.service_connection_id : var.azdo_service_connection_id) : null
  azdo_token                   = var.azdo_org_url != null && var.azdo_pat != null ? var.azdo_pat : data.external.azdo_token.result.accessToken

  create_azdo_environment      = (var.azdo_self_hosted_pool_type == "Environment" && !(var.azdo_self_hosted_pool_name != null && var.azdo_self_hosted_pool_name != ""))
  create_azdo_linux_scale_set_pool= (local.create_azdo_resources && var.deploy_azure_scale_set && var.azure_linux_scale_set_agent_count > 0)
  create_azdo_resources        = var.azdo_org_url != null && var.azdo_org_url != "" && length(var.azdo_project_names) > 0
  create_azdo_self_hosted_pool = (var.azdo_self_hosted_pool_type == "AgentPool" && var.azdo_self_hosted_pool_name != null && var.azdo_self_hosted_pool_name != "")
  create_azdo_service_connection= !(var.azdo_service_connection_id != null && var.azdo_service_connection_id != "")
  create_azdo_windows_scale_set_pool= (local.create_azdo_resources && var.deploy_azure_scale_set && var.azure_windows_scale_set_agent_count > 0)
}

# data http environments {
#   url                          = "${data.azuredevops_client_config.current.organization_url}/${local.azdo_project_id}/_apis/pipelines/environments?api-version=7.1"
#   request_headers = {
#     Accept                     = "application/json"
#     Authorization              = "Bearer ${data.external.azdo_token.result.accessToken}"
#   }

#   lifecycle {
#     postcondition {
#       condition                = tonumber(self.status_code) < 300
#       error_message            = "Could not retrieve account information"
#     }
#   }
# }
# output azdo_environments {
#   value                        = jsondecode(data.http.environments.response_body).value
# }
# output azdo_environments_url {
#   value                        = data.http.environments.url
# }