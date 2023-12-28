data azuredevops_client_config current {}

locals {
  pool_id                      = var.create_pool ? azuredevops_agent_pool.agent_pool.0.id : data.azuredevops_agent_pool.agent_pool.0.id
}

data azuredevops_agent_pool agent_pool {
  name                         = var.name

  count                        = var.create_pool ? 0 : 1
}

resource azuredevops_agent_pool agent_pool {
  name                         = var.name
  auto_update                  = true # Default

  count                        = var.create_pool ? 1 : 0
}

resource azuredevops_agent_queue project_pool {
  project_id                   = each.value
  agent_pool_id                = azuredevops_agent_pool.agent_pool.0.id

  for_each                     = var.create_pool ? toset(var.project_ids) : toset([])
}

# Grant access to queue to all pipelines in the project
resource azuredevops_pipeline_authorization project_pool {
  project_id                   = each.value
  resource_id                  = azuredevops_agent_queue.project_pool[each.value].id
  type                         = "queue"

  for_each                     = var.create_pool ? toset(var.project_ids) : toset([])
}