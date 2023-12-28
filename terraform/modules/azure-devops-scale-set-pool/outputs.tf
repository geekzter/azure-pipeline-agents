output id {
  value                        = azuredevops_elastic_pool.scale_set_pool.id
}
output name {
  value                        = azuredevops_elastic_pool.scale_set_pool.name
}
output url {
  value                        = "${data.azuredevops_client_config.current.organization_url}/_settings/agentpools?poolId=${azuredevops_elastic_pool.scale_set_pool.id}&view=agents"
}