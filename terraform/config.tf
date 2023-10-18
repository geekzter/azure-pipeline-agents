resource azurerm_storage_container configuration {
  name                         = "configuration"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "private"

  count                        = var.configure_access_control ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
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
      "serviceEndpointId"      = var.azdo_service_connection_id
      "serviceEndpointScope"   = var.azdo_project
      "azureId"                = vmss.id
      "maxCapacity"            = vmss.max_count
      "desiredIdle"            = min(vmss.count,vmss.max_count,coalesce(vmss.os == "windows" ? var.windows_scale_set_agent_idle_count : var.linux_scale_set_agent_idle_count),vmss.count)
      "recycleAfterEachUse"    = true
      "maxSavedNodeCount"      = max(0,vmss.max_count - vmss.count,vmss.os == "windows" ? var.windows_scale_set_agent_max_saved_count : var.linux_scale_set_agent_max_saved_count)
      "osType"                 = vmss.os
      "desiredSize"            = min(vmss.count+1,vmss.max_count)
      "agentInteractiveUI"     = vmss.os == "windows" ? var.windows_scale_set_agent_interactive_ui : false
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
  storage_container_name       = azurerm_storage_container.configuration.0.name
  type                         = "Block"
  source_content               = local.set_environment_variables_script

  count                        = var.configure_access_control ? 1 : 0
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
  storage_container_name       = azurerm_storage_container.configuration.0.name
  type                         = "Block"
  source_content               = jsonencode(each.value)

  for_each                     = var.configure_access_control ? local.elastic_pools : tomap({})
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}
resource azurerm_storage_blob terraform_backend_configuration {
  name                         = "terraform/backend.tf"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.0.name
  type                         = "Block"
  source                       = "${path.root}/backend.tf"

  count                        = var.configure_access_control && fileexists("${path.root}/backend.tf") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}
resource azurerm_storage_blob terraform_auto_vars_configuration {
  name                         = "terraform/config.auto.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.0.name
  type                         = "Block"
  source                       = "${path.root}/config.auto.tfvars"

  count                        = var.configure_access_control && fileexists("${path.root}/config.auto.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}
resource azurerm_storage_blob terraform_workspace_vars_configuration {
  name                         = "terraform/${terraform.workspace}.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.0.name
  type                         = "Block"
  source                       = "${path.root}/${terraform.workspace}.tfvars"

  count                        = var.configure_access_control && fileexists("${path.root}/${terraform.workspace}.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}