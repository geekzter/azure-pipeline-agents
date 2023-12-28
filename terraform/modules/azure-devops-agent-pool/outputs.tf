output id {
  value                        = local.pool_id
}
output name {
  value                        = var.create_pool ? azuredevops_agent_pool.agent_pool.0.name : var.name
}
output url {
  value                        = "${data.azuredevops_client_config.current.organization_url}/_settings/agentpools?poolId=${local.pool_id}&view=agents"
}