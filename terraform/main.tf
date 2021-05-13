# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  number                       = false
  special                      = false
}

# Random password generator
resource random_string password {
  length                       = 12
  upper                        = true
  lower                        = true
  number                       = true
  special                      = true
# override_special             = "!@#$%&*()-_=+[]{}<>:?" # default
# Avoid characters that may cause shell scripts to break
  override_special             = "." 
}

locals {
  config_directory             = "${formatdate("YYYY",timestamp())}/${formatdate("MM",timestamp())}/${formatdate("DD",timestamp())}/${formatdate("hhmm",timestamp())}"
  environment                  = "dev"
  password                     = ".Az9${random_string.password.result}"
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  tags                         = {
    application                = "Pipeline Agents"
    environment                = local.environment
    provisioner                = "terraform"
    repository                 = "azure-pipeline-agents"
    runid                      = var.run_id
    shutdown                   = "false"
    suffix                     = local.suffix
    workspace                  = terraform.workspace
  }
}

data azurerm_client_config current {}


resource azurerm_resource_group rg {
  name                         = terraform.workspace == "default" ? "azure-pipelines-agents-${local.suffix}" : "azure-pipelines-agents-${terraform.workspace}-${local.suffix}"
  location                     = var.location
  tags                         = local.tags
}

resource azurerm_storage_account automation_storage {
  name                         = "${substr(lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/","")),0,16)}${local.suffix}stor"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_blob_public_access     = true
  enable_https_traffic_only    = true

  tags                         = local.tags
}
resource azurerm_storage_container scripts {
  name                         = "scripts"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "container"
}
resource azurerm_storage_container configuration {
  name                         = "configuration"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "private"
}

resource azurerm_role_assignment terraform_storage_owner {
  scope                        = azurerm_storage_account.automation_storage.id
  role_definition_name         = "Storage Blob Data Contributor"
  principal_id                 = data.azurerm_client_config.current.object_id
}

resource azurerm_storage_blob terraform_backend_configuration {
  name                         = "${local.config_directory}/backend.tf"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/backend.tf"

  count                        = fileexists("${path.root}/backend.tf") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}
resource azurerm_storage_blob terraform_auto_vars_configuration {
  name                         = "${local.config_directory}/config.auto.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/config.auto.tfvars"

  count                        = fileexists("${path.root}/config.auto.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}
resource azurerm_storage_blob terraform_workspace_vars_configuration {
  name                         = "${local.config_directory}/${terraform.workspace}.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/${terraform.workspace}.tfvars"

  count                        = fileexists("${path.root}/${terraform.workspace}.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}