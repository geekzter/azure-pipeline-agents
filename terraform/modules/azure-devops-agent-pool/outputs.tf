output id {
  value                        = var.create_pool ? azuredevops_agent_pool.agent_pool.0.id : data.azuredevops_agent_pool.agent_pool.0.id
}
output name {
  value                        = var.create_pool ? azuredevops_agent_pool.agent_pool.0.name : var.name
}