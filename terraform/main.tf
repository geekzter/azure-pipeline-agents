# Data sources
data azurerm_resource_group pipeline_resource_group {
  name                         = var.pipeline_resource_group
}

data azurerm_virtual_network pipeline_network {
  name                         = var.pipeline_network
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
}

data azurerm_subnet pipeline_subnet {
  name                         = var.pipeline_subnet
  virtual_network_name         = data.azurerm_virtual_network.pipeline_network.name
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
}

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
      "environment",             "pipelines",
      "suffix",                  local.suffix,
      "workspace",               terraform.workspace
  )
}

resource azurerm_network_security_group nsg {
  name                         = "${local.linux_vm_name}-nsg"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name

  security_rule {
    name                       = "InboundRDP"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "InboundSSH"
    priority                   = 202
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags                         = local.tags
}

resource azurerm_storage_account automation_storage {
  name                         = "${lower(replace(data.azurerm_resource_group.pipeline_resource_group.name,"-",""))}${local.suffix}stor"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  enable_https_traffic_only    = true

  tags                         = local.tags
}

resource azurerm_storage_container scripts {
  name                         = "scripts"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "container"
}