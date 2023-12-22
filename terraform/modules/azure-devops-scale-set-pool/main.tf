resource  azuredevops_elastic_pool scale_set_pool {
  name                         = var.name
  service_endpoint_id          = var.service_connection_id
  service_endpoint_scope       = var.project_id
  desired_idle                 = var.min_capacity
  max_capacity                 = var.max_capacity
  azure_resource_id            = var.vmss_id
  recycle_after_each_use       = var.recycle_after_each_use
  time_to_live_minutes         = 30
}

resource azuredevops_agent_queue project_pool {
  project_id                   = var.project_id
  agent_pool_id                = azuredevops_elastic_pool.scale_set_pool.id
}

# Grant access to queue to all pipelines in the project
resource azuredevops_pipeline_authorization project_pool {
  project_id                   = var.project_id
  resource_id                  = azuredevops_agent_queue.project_pool.id
  type                         = "queue"
}