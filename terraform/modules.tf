module network {
  source                       = "./modules/network"

  address_space                = var.address_space
  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  dns_host_suffix              = var.dns_host_suffix
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags
  use_firewall                 = var.use_firewall
}

module scale_set_agents {
  source                       = "./modules/scale-set-agents"

  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  linux_agent_count            = var.linux_scale_set_agent_count
  linux_pipeline_agent_name    = var.linux_pipeline_agent_name
  linux_pipeline_agent_pool    = var.linux_pipeline_agent_pool
  linux_os_offer               = var.linux_os_offer
  linux_os_publisher           = var.linux_os_publisher
  linux_os_sku                 = var.linux_os_sku
  linux_storage_type           = var.linux_storage_type
  linux_vm_name_prefix         = var.linux_vm_name_prefix
  linux_vm_size                = var.linux_vm_size

  outbound_ip_address          = module.network.outbound_ip_address
  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = module.network.agent_subnet_id
  suffix                       = local.suffix
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.use_scale_set ? 1 : 0
  depends_on                   = [module.network]
}

module self_hosted_linux_agents {
  source                       = "./modules/self-hosted-linux-agent"

  admin_cidr_ranges            = local.admin_cidr_ranges
  terraform_cidr               = local.ipprefix

  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  os_offer                     = var.linux_os_offer
  os_publisher                 = var.linux_os_publisher
  os_sku                       = var.linux_os_sku
  pipeline_agent_name          = "${var.linux_pipeline_agent_name}${count.index+1}"
  pipeline_agent_pool          = var.linux_pipeline_agent_pool
  storage_type                 = var.linux_storage_type
  vm_name_prefix               = "${var.linux_vm_name_prefix}${count.index+1}"
  vm_size                      = var.linux_vm_size

  outbound_ip_address          = module.network.outbound_ip_address
  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = module.network.agent_subnet_id
  suffix                       = local.suffix
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.use_self_hosted ? var.linux_self_hosted_agent_count : 0
  depends_on                   = [module.network]
}

module self_hosted_windows_agents {
  source                       = "./modules/self-hosted-windows-agent"

  admin_cidr_ranges            = local.admin_cidr_ranges
  terraform_cidr               = local.ipprefix

  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  os_offer                     = var.windows_os_offer
  os_publisher                 = var.windows_os_publisher
  os_sku                       = var.windows_os_sku
  pipeline_agent_name          = "${var.windows_pipeline_agent_name}${count.index+1}"
  pipeline_agent_pool          = var.windows_pipeline_agent_pool
  storage_type                 = var.windows_storage_type
  vm_name_prefix               = "${var.windows_vm_name_prefix}${count.index+1}"
  vm_size                      = var.windows_vm_size

  # outbound_ip_address          = module.network.outbound_ip_address # TODO
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags
  subnet_id                    = module.network.agent_subnet_id
  suffix                       = local.suffix
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.use_self_hosted ? var.windows_self_hosted_agent_count : 0
  depends_on                   = [module.network]
}