resource azurerm_storage_account diagnostics {
  name                         = "${substr(lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/","")),0,14)}${substr(local.suffix,-6,-1)}diag"
  location                     = var.azure_location
  resource_group_name          = azurerm_resource_group.rg.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  https_traffic_only_enabled   = false
  shared_access_key_enabled    = false

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
    add                        = true
    create                     = true
    delete                     = false
    filter                     = false
    list                       = true
    process                    = false
    read                       = false
    tag                        = false
    update                     = true
    write                      = true
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

  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.subnet_id}"
  }

  tags                         = local.tags

  depends_on                   = [
    azurerm_private_endpoint.vault_endpoint,
    module.network
  ]
  count                        = var.deploy_azure_firewall ? 1 : 0
}

resource azurerm_storage_account automation_storage {
  name                         = "${substr(lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/","")),0,15)}${substr(local.suffix,-6,-1)}aut"
  location                     = var.azure_location
  resource_group_name          = azurerm_resource_group.rg.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  https_traffic_only_enabled   = true
  shared_access_key_enabled    = false

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

  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.subnet_id}"
  }

  tags                         = local.tags

  depends_on                   = [
    azurerm_private_endpoint.diag_blob_storage_endpoint,
    module.network
  ]
  count                        = var.deploy_azure_firewall ? 1 : 0
}

resource azurerm_disk_access disk_access {
  name                         = "${azurerm_resource_group.rg.name}-disk-access"
  location                     = var.azure_location
  resource_group_name          = azurerm_resource_group.rg.name

  tags                         = local.tags
}

resource azurerm_private_endpoint disk_access_endpoint {
  name                         = "${azurerm_disk_access.disk_access.name}-endpoint"
  location                     = var.azure_location
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

  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.subnet_id}"
  }

  tags                         = local.tags

  depends_on                   = [
    azurerm_private_endpoint.aut_blob_storage_endpoint,
    module.network
  ]
  count                        = var.deploy_azure_firewall ? 1 : 0
}

resource azurerm_storage_account share {
  name                         = "${substr(lower(replace(azurerm_resource_group.rg.name,"/a|e|i|o|u|y|-/","")),0,14)}${substr(local.suffix,-6,-1)}shar"
  location                     = var.azure_location
  resource_group_name          = azurerm_resource_group.rg.name
  account_kind                 = "FileStorage"
  account_tier                 = "Premium"
  account_replication_type     = "LRS"
  default_to_oauth_authentication = true
  https_traffic_only_enabled   = false # Needs to be off for NFS
  shared_access_key_enabled    = true # Azure Files Share does not support Entra ID AuthN yet

  tags                         = local.tags

  count                        = var.deploy_azure_files_share ? 1 : 0
}

resource azurerm_storage_share diagnostics_smb_share {
  name                         = "diagnostics"
  storage_account_name         = azurerm_storage_account.share.0.name
  enabled_protocol             = "SMB"
  quota                        = 128

  count                        = var.deploy_azure_files_share ? 1 : 0
}
resource azurerm_private_endpoint diagnostics_share {
  name                         = "${azurerm_storage_account.share.0.name}-files-endpoint"
  location                     = var.azure_location
  resource_group_name          = azurerm_resource_group.rg.name
  
  subnet_id                    = module.network.private_endpoint_subnet_id

  private_dns_zone_group {
    name                       = module.network.azurerm_private_dns_zone_file_name
    private_dns_zone_ids       = [module.network.azurerm_private_dns_zone_file_id]
  }
  
  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_storage_account.share.0.name}-files-endpoint-connection"
    private_connection_resource_id = azurerm_storage_account.share.0.id
    subresource_names          = ["file"]
  }

  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.subnet_id}"
  }

  tags                         = local.tags

  depends_on                   = [
    azurerm_private_endpoint.disk_access_endpoint,
    module.network
  ]

  count                        = var.deploy_azure_files_share ? 1 : 0
}
resource azurerm_storage_share_file sync_windows_vm_logs_cmd {
  name                         = "sync_windows_vm_logs.cmd"
  storage_share_id             = azurerm_storage_share.diagnostics_smb_share.0.id
  source                       = "${path.root}/../scripts/host/sync_windows_vm_logs.cmd"

  count                        = var.deploy_azure_files_share ? 1 : 0
}
resource azurerm_storage_share_file sync_windows_vm_logs_ps1 {
  name                         = "sync_windows_vm_logs.ps1"
  storage_share_id             = azurerm_storage_share.diagnostics_smb_share.0.id
  source                       = "${path.root}/../scripts/host/sync_windows_vm_logs.ps1"

  count                        = var.deploy_azure_files_share ? 1 : 0
}

locals {
  diagnostics_smb_share        = var.deploy_azure_files_share ? replace(azurerm_storage_share.diagnostics_smb_share.0.url,"https:","") : null
  diagnostics_smb_share_mount_point= var.deploy_azure_files_share ? "/mount/${azurerm_storage_account.share.0.name}/${azurerm_storage_share.diagnostics_smb_share.0.name}" : null
}
