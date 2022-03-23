resource azurerm_storage_account diagnostics {
  name                         = "${substr(lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/","")),0,14)}${substr(local.suffix,-6,-1)}diag"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_blob_public_access     = false
  enable_https_traffic_only    = true

  tags                         = local.tags
}
resource time_offset sas_expiry {
  offset_years                 = 1
}
resource time_offset sas_start {
  offset_days                  = -1
}
data azurerm_storage_account_sas diagnostics {
  connection_string            = azurerm_storage_account.diagnostics.primary_connection_string
  https_only                   = true

  resource_types {
    service                    = false
    container                  = true
    object                     = true
  }

  services {
    blob                       = true
    queue                      = false
    table                      = true
    file                       = false
  }

  start                        = time_offset.sas_start.rfc3339
  expiry                       = time_offset.sas_expiry.rfc3339  

  permissions {
    read                       = false
    add                        = true
    create                     = true
    write                      = true
    delete                     = false
    list                       = true
    update                     = true
    process                    = false
  }
}

resource azurerm_private_endpoint diag_blob_storage_endpoint {
  name                         = "${azurerm_storage_account.diagnostics.name}-blob-endpoint"
  resource_group_name          = azurerm_storage_account.diagnostics.resource_group_name
  location                     = azurerm_storage_account.diagnostics.location
  
  subnet_id                    = module.network.private_endpoint_subnet_id

  private_dns_zone_group {
    name                       = module.network.azurerm_private_dns_zone_blob_name
    private_dns_zone_ids       = [module.network.azurerm_private_dns_zone_blob_id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_storage_account.diagnostics.name}-blob-endpoint-connection"
    private_connection_resource_id = azurerm_storage_account.diagnostics.id
    subresource_names          = ["blob"]
  }

  tags                         = local.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_storage_account automation_storage {
  name                         = "${substr(lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/","")),0,15)}${substr(local.suffix,-6,-1)}aut"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_blob_public_access     = false
  enable_https_traffic_only    = true

  tags                         = local.tags
}
resource azurerm_private_endpoint aut_blob_storage_endpoint {
  name                         = "${azurerm_storage_account.automation_storage.name}-blob-endpoint"
  resource_group_name          = azurerm_storage_account.automation_storage.resource_group_name
  location                     = azurerm_storage_account.automation_storage.location
  
  subnet_id                    = module.network.private_endpoint_subnet_id

  private_dns_zone_group {
    name                       = module.network.azurerm_private_dns_zone_blob_name
    private_dns_zone_ids       = [module.network.azurerm_private_dns_zone_blob_id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_storage_account.automation_storage.name}-blob-endpoint-connection"
    private_connection_resource_id = azurerm_storage_account.automation_storage.id
    subresource_names          = ["blob"]
  }

  tags                         = local.tags

  count                        = var.deploy_firewall ? 1 : 0
}
resource azurerm_storage_container configuration {
  name                         = "configuration"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "private"
}

resource azurerm_storage_blob terraform_backend_configuration {
  name                         = "${local.config_directory}/backend.tf"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/backend.tf"

  count                        = fileexists("${path.root}/backend.tf") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}
resource azurerm_storage_blob terraform_auto_vars_configuration {
  name                         = "${local.config_directory}/config.auto.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/config.auto.tfvars"

  count                        = fileexists("${path.root}/config.auto.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}
resource azurerm_storage_blob terraform_workspace_vars_configuration {
  name                         = "${local.config_directory}/${terraform.workspace}.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/${terraform.workspace}.tfvars"

  count                        = fileexists("${path.root}/${terraform.workspace}.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.agent_storage_contributors]
}

resource azurerm_disk_access disk_access {
  name                         = "${azurerm_resource_group.rg.name}-disk-access"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name

  tags                         = local.tags
}

resource azurerm_private_endpoint disk_access_endpoint {
  name                         = "${azurerm_disk_access.disk_access.name}-endpoint"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  
  subnet_id                    = module.network.private_endpoint_subnet_id

  private_dns_zone_group {
    name                       = module.network.azurerm_private_dns_zone_blob_name
    private_dns_zone_ids       = [module.network.azurerm_private_dns_zone_blob_id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_disk_access.disk_access.name}-endpoint-connection"
    private_connection_resource_id = azurerm_disk_access.disk_access.id
    subresource_names          = ["disks"]
  }

  tags                         = local.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_storage_account share {
  name                         = "${substr(lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/","")),0,14)}${substr(local.suffix,-6,-1)}shar"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  account_kind                 = "FileStorage"
  account_tier                 = "Premium"
  account_replication_type     = "LRS"
  enable_https_traffic_only    = false # Needs to be off for NFS
}

resource azurerm_storage_share diagnostics_nfs_share {
  name                         = "diagnosticsnfs"
  storage_account_name         = azurerm_storage_account.share.name
  enabled_protocol             = "NFS"
}

locals {
  diagnostics_nfs_share        = "${azurerm_storage_account.share.primary_file_host}:/${azurerm_storage_account.share.name}/${azurerm_storage_share.diagnostics_nfs_share.name}"
  diagnostics_nfs_share_mount_point= "/mount/${azurerm_storage_account.share.name}/${azurerm_storage_share.diagnostics_nfs_share.name}"
}

resource azurerm_private_endpoint diagnostics_nfs_share {
  name                         = "${azurerm_storage_account.share.name}-nfs-share-endpoint"
  resource_group_name          = azurerm_storage_account.share.resource_group_name
  location                     = azurerm_storage_account.share.location
  
  subnet_id                    = module.network.private_endpoint_subnet_id

  private_dns_zone_group {
    name                       = module.network.azurerm_private_dns_zone_file_name
    private_dns_zone_ids       = [module.network.azurerm_private_dns_zone_file_id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_storage_account.share.name}-nfs-share-endpoint-connection"
    private_connection_resource_id = azurerm_storage_account.share.id
    subresource_names          = ["file"]
  }

  tags                         = local.tags
}