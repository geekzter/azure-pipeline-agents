output id {
  value                        = local.environment_id
}
output name {
  value                        = var.create_environment ? azuredevops_environment.environment.0.name : data.azuredevops_environment.environment.0.name
}
output url {
  value                        = "${data.azuredevops_client_config.current.organization_url}/${var.project_id}/_environments/${local.environment_id}?view=resources"
}