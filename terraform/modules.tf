module network {
  source                       = "./modules/network"

  address_space                = var.address_space
  admin_cidr_ranges            = local.admin_cidr_ranges
  configuration_name           = local.configuration_bitmask
  configure_cidr_allow_rules   = var.configure_cidr_allow_rules
  configure_crl_oscp_rules     = var.configure_crl_oscp_rules
  configure_wildcard_allow_rules= var.configure_wildcard_allow_rules
  deploy_bastion               = var.deploy_bastion
  deploy_firewall              = var.deploy_firewall
  destroy_wait_minutes         = var.destroy_wait_minutes
  devops_org                   = var.devops_org
  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  dns_host_suffix              = var.dns_host_suffix
  enable_firewall_dns_proxy    = var.enable_firewall_dns_proxy
  enable_public_access         = var.enable_public_access
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id
  packer_address_space         = var.packer_address_space
  peer_virtual_network_id      = module.packer.virtual_network_id
  resource_group_name          = azurerm_resource_group.rg.name
  packer_storage_account_name  = module.packer.storage_account_name
  packer_storage_ip_address    = module.packer.storage_blob_ip_address
  tags                         = local.tags
}

module packer {
  source                       = "./modules/packer"

  providers                    = {
    azurerm                    = azurerm.peer
  }

  address_space                = var.packer_address_space
  admin_cidr_ranges            = local.admin_cidr_ranges
  agent_address_range          = module.network.agent_address_range
  deploy_nat_gateway           = !var.deploy_firewall
  gateway_ip_address           = module.network.gateway_ip_address
  peer_virtual_network_id      = module.network.virtual_network_id
  location                     = var.location
  suffix                       = local.suffix
  tags                         = local.tags

  depends_on                   = [
    time_sleep.script_wrapper_check
  ]
}

module scale_set_linux_agents {
  source                       = "./modules/scale-set-linux-agents"

  deploy_files_share           = var.deploy_files_share
  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  diagnostics_smb_share        = local.diagnostics_smb_share
  diagnostics_smb_share_mount_point= local.diagnostics_smb_share_mount_point
  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  environment_variables        = local.environment_variables
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  linux_agent_count            = var.linux_scale_set_agent_count
  linux_os_image_id            = local.linux_image_id
  linux_os_offer               = var.linux_os_offer
  linux_os_publisher           = var.linux_os_publisher
  linux_os_sku                 = var.linux_os_sku
  linux_os_version             = var.linux_os_version
  linux_storage_type           = var.linux_storage_type
  linux_vm_name_prefix         = "ubuntu-agent"
  linux_vm_size                = var.linux_vm_size

  outbound_ip_address          = module.network.outbound_ip_address
  install_tools                = var.linux_tools
  prepare_host                 = var.prepare_host
  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = module.network.scale_set_agents_subnet_id
  suffix                       = local.suffix
  user_assigned_identity_id    = azurerm_user_assigned_identity.agents.id
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.deploy_scale_set && var.linux_scale_set_agent_count > 0 ? 1 : 0
  depends_on                   = [
    azurerm_private_endpoint.aut_blob_storage_endpoint,
    azurerm_private_endpoint.diag_blob_storage_endpoint,
    azurerm_private_endpoint.diagnostics_share,
    azurerm_private_endpoint.disk_access_endpoint,
    module.network
  ]
}

module scale_set_windows_agents {
  source                       = "./modules/scale-set-windows-agents"

  deploy_files_share           = var.deploy_files_share
  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  diagnostics_smb_share        = local.diagnostics_smb_share
  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  environment_variables        = local.environment_variables
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  windows_agent_count          = var.windows_scale_set_agent_count
  windows_os_image_id          = local.windows_image_id
  windows_os_offer             = var.windows_os_offer
  windows_os_publisher         = var.windows_os_publisher
  windows_os_sku               = var.windows_os_sku
  windows_os_version           = var.windows_os_version
  windows_storage_type         = var.windows_storage_type
  windows_vm_name_prefix       = "windows-agent"
  windows_vm_size              = var.windows_vm_size

  outbound_ip_address          = module.network.outbound_ip_address
  prepare_host                 = var.prepare_host
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags
  subnet_id                    = module.network.scale_set_agents_subnet_id
  suffix                       = local.suffix
  user_assigned_identity_id    = azurerm_user_assigned_identity.agents.id
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.deploy_scale_set && var.windows_scale_set_agent_count > 0 ? 1 : 0
  depends_on                   = [
    azurerm_private_endpoint.aut_blob_storage_endpoint,
    azurerm_private_endpoint.diag_blob_storage_endpoint,
    azurerm_private_endpoint.disk_access_endpoint,
    module.network
  ]
}

module self_hosted_linux_agents {
  source                       = "./modules/self-hosted-linux-agent"

  admin_cidr_ranges            = local.admin_cidr_ranges

  create_public_ip_address     = !var.deploy_firewall
  deploy_agent                 = var.devops_org != null && var.devops_pat != null && var.deploy_self_hosted_vm_agents
  deploy_files_share           = var.deploy_files_share
  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_smb_share        = local.diagnostics_smb_share
  diagnostics_smb_share_mount_point= local.diagnostics_smb_share_mount_point
  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  environment_variables        = local.environment_variables
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  computer_name                = "linuxagent${count.index+1}"
  disk_access_name             = azurerm_disk_access.disk_access.name
  name                         = "${azurerm_resource_group.rg.name}-linux-agent${count.index+1}"
  os_image_id                  = local.linux_image_id
  os_offer                     = var.linux_os_offer
  os_publisher                 = var.linux_os_publisher
  os_sku                       = var.linux_os_sku
  os_version                   = var.linux_os_version
  pipeline_agent_name          = "${var.linux_pipeline_agent_name_prefix}-${terraform.workspace}${count.index+1}"
  pipeline_agent_pool          = var.linux_pipeline_agent_pool
  pipeline_agent_version_id    = var.pipeline_agent_version_id
  storage_type                 = var.linux_storage_type
  vm_size                      = var.linux_vm_size

  enable_public_access         = var.enable_public_access
  install_tools                = var.linux_tools
  outbound_ip_address          = module.network.outbound_ip_address
  prepare_host                 = var.prepare_host
  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = module.network.self_hosted_agents_subnet_id
  suffix                       = local.suffix
  user_assigned_identity_id    = azurerm_user_assigned_identity.agents.id
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.deploy_self_hosted_vms ? var.linux_self_hosted_agent_count : 0
  depends_on                   = [
    azurerm_private_endpoint.aut_blob_storage_endpoint,
    azurerm_private_endpoint.diag_blob_storage_endpoint,
    azurerm_private_endpoint.diagnostics_share,
    azurerm_private_endpoint.disk_access_endpoint,
    module.network
  ]
}

module self_hosted_windows_agents {
  source                       = "./modules/self-hosted-windows-agent"

  admin_cidr_ranges            = local.admin_cidr_ranges

  create_public_ip_address     = !var.deploy_firewall
  deploy_agent_vm_extension    = var.devops_org != null && var.devops_pat != null && var.deploy_self_hosted_vm_agents
  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  environment_variables        = local.environment_variables
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  computer_name                = "windowsagent${count.index+1}"
  disk_access_name             = azurerm_disk_access.disk_access.name
  name                         = "${azurerm_resource_group.rg.name}-windows-agent${count.index+1}"
  os_image_id                  = local.windows_image_id
  os_offer                     = var.windows_os_offer
  os_publisher                 = var.windows_os_publisher
  os_sku                       = var.windows_os_sku
  os_version                   = var.windows_os_version
  pipeline_agent_name          = "${var.windows_pipeline_agent_name_prefix}-${terraform.workspace}${count.index+1}"
  pipeline_agent_pool          = var.windows_pipeline_agent_pool
  pipeline_agent_version_id    = var.pipeline_agent_version_id
  storage_type                 = var.windows_storage_type
  vm_size                      = var.windows_vm_size

  enable_public_access         = var.enable_public_access
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags
  subnet_id                    = module.network.self_hosted_agents_subnet_id
  suffix                       = local.suffix
  user_assigned_identity_id    = azurerm_user_assigned_identity.agents.id
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.deploy_self_hosted_vms ? var.windows_self_hosted_agent_count : 0
  depends_on                   = [
    azurerm_private_endpoint.aut_blob_storage_endpoint,
    azurerm_private_endpoint.diag_blob_storage_endpoint,
    azurerm_private_endpoint.disk_access_endpoint,
    module.network
  ]
}

module gallery {
  source                       = "./modules/gallery"

  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags
  admin_cidr_ranges            = local.admin_cidr_ranges
  blob_private_dns_zone_id     = module.network.azurerm_private_dns_zone_blob_id
  shared_image_gallery_id      = var.shared_image_gallery_id
  storage_account_tier         = var.vhd_storage_account_tier
  subnet_id                    = module.network.private_endpoint_subnet_id
  suffix                       = local.suffix

  depends_on                   = [
    azurerm_role_assignment.agent_storage_contributors,
    module.network,
    module.packer
  ]
}