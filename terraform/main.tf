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
  password                     = ".Az9${random_string.password.result}"
  suffix                       = random_string.suffix.result
  tags                         = map(
      "application",             "Pipeline Agents",
      "environment",             "dev",
      "provisioner",             "terraform",
      "repository",              "azure-pipeline-agents",
      "shutdown",                "false",
      "suffix",                  local.suffix,
      "workspace",               terraform.workspace
  )
}

resource azurerm_resource_group rg {
  name                         = "azure-pipelines-agents-${local.suffix}"
  location                     = var.location
  tags                         = local.tags
}

resource azurerm_virtual_network pipeline_network {
  name                         = "${azurerm_resource_group.rg.name}-${var.location}-network"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  address_space                = [var.address_space]

  tags                         = local.tags
}

resource azurerm_subnet agent_subnet {
  name                         = "PipelineAgents"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],8,1)]
}

resource azurerm_storage_account automation_storage {
  name                         = "${lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/",""))}${local.suffix}stor"
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