data azuredevops_client_config current {}

resource  azuredevops_elastic_pool scale_set_pool {
  name                         = var.name
  agent_interactive_ui         = var.agent_interactive_ui
  service_endpoint_id          = var.service_connection_id
  service_endpoint_scope       = var.project_ids[0]
  desired_idle                 = var.min_capacity
  max_capacity                 = var.max_capacity
  azure_resource_id            = var.vmss_id
  recycle_after_each_use       = var.recycle_after_each_use
  time_to_live_minutes         = 30
}

resource azuredevops_agent_queue project_pool {
  project_id                   = each.value
  agent_pool_id                = azuredevops_elastic_pool.scale_set_pool.id

  for_each                     = toset(var.project_ids)
}

# Grant access to queue to all pipelines in the project
resource azuredevops_pipeline_authorization project_pool {
  project_id                   = each.value
  resource_id                  = azuredevops_agent_queue.project_pool[each.value].id
  type                         = "queue"

  for_each                     = toset(var.project_ids)
}