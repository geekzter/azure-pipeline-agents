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