resource azurerm_storage_container configuration {
  name                         = "configuration"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "private"
}

locals {
  set_environment_variables_script = templatefile("${path.root}/../scripts/set_environment_variables.template.ps1",
  {
    environment                = local.environment_variables
  })
  
  virtual_machine_scale_sets   = merge(
    {for vmss in module.scale_set_linux_agents   : "linux"   => {
      id                       = vmss.virtual_machine_scale_set_id
      count                    = var.linux_scale_set_agent_count
      max_count                = var.linux_scale_set_agent_max_count
      os                       = "linux"
    }},
    {for vmss in module.scale_set_windows_agents : "windows" => {
      id                       = vmss.virtual_machine_scale_set_id
      count                    = var.windows_scale_set_agent_count
      max_count                = var.windows_scale_set_agent_max_count
      os                       = "windows"
    }}
  )

  elastic_pools                = {
    for vmss in local.virtual_machine_scale_sets : vmss.os => {
      "serviceEndpointId"      = var.service_connection_id
      "serviceEndpointScope"   = var.service_connection_project
      "azureId"                = vmss.id
      "maxCapacity"            = vmss.max_count
      "desiredIdle"            = min(vmss.count,vmss.max_count)
      "recycleAfterEachUse"    = true
      "maxSavedNodeCount"      = 1
      "osType"                 = vmss.os
      "desiredSize"            = min(vmss.count+1,vmss.max_count)
      "agentInteractiveUI"     = false
      "timeToLiveMinutes"      = 30
    }
  }
}

resource local_file set_environment_variables_script {
  content                      = local.set_environment_variables_script
  filename                     = "${path.root}/../data/${terraform.workspace}/set_environment_variables.ps1"
}
resource azurerm_storage_blob set_environment_variables_script {
  name                         = "data/${terraform.workspace}/set_environment_variables.ps1"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source_content               = local.set_environment_variables_script

  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}

resource local_file elastic_pools {
  content                      = jsonencode(each.value)
  filename                     = "${path.root}/../data/${terraform.workspace}/${each.key}_elastic_pool.json"

  for_each                     = local.elastic_pools
}
resource azurerm_storage_blob scale_set_pool_config {
  name                         = "data/${terraform.workspace}/${each.key}_elastic_pool.json"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source_content               = jsonencode(each.value)

  for_each                     = local.elastic_pools
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}
resource azurerm_storage_blob terraform_backend_configuration {
  name                         = "terraform/backend.tf"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/backend.tf"

  count                        = fileexists("${path.root}/backend.tf") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}
resource azurerm_storage_blob terraform_auto_vars_configuration {
  name                         = "terraform/config.auto.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/config.auto.tfvars"

  count                        = fileexists("${path.root}/config.auto.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}
resource azurerm_storage_blob terraform_workspace_vars_configuration {
  name                         = "terraform/${terraform.workspace}.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/${terraform.workspace}.tfvars"

  count                        = fileexists("${path.root}/${terraform.workspace}.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}