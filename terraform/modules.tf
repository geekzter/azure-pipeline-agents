module network {
  source                       = "./modules/network"

  address_space                = var.address_space
  configuration_name           = local.configuration_bitmask
  configure_cidr_allow_rules   = var.configure_cidr_allow_rules
  configure_wildcard_allow_rules= var.configure_wildcard_allow_rules
  deploy_bastion               = var.deploy_bastion
  deploy_firewall              = var.deploy_firewall
  devops_org                   = var.devops_org
  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  dns_host_suffix              = var.dns_host_suffix
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags
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
  linux_pipeline_agent_name    = "ubuntu-agent"
  linux_pipeline_agent_pool    = var.linux_pipeline_agent_pool
  linux_os_offer               = var.linux_os_offer
  linux_os_publisher           = var.linux_os_publisher
  linux_os_sku                 = var.linux_os_sku
  linux_storage_type           = var.linux_storage_type
  linux_vm_name_prefix         = "ubuntu-agent"
  linux_vm_size                = var.linux_vm_size

  outbound_ip_address          = module.network.outbound_ip_address
  prepare_host                 = var.prepare_host
  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = module.network.scale_set_agents_subnet_id
  suffix                       = local.suffix
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.deploy_scale_set ? 1 : 0
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
  terraform_cidr               = local.ipprefix

  create_public_ip_address     = !var.deploy_firewall
  deploy_agent                 = var.deploy_self_hosted_vm_agents
  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  computer_name                = "linuxagent${count.index+1}"
  disk_access_name             = azurerm_disk_access.disk_access.name
  name                         = "${azurerm_resource_group.rg.name}-linux-agent${count.index+1}"
  os_offer                     = var.linux_os_offer
  os_publisher                 = var.linux_os_publisher
  os_sku                       = var.linux_os_sku
  pipeline_agent_name          = "${var.linux_pipeline_agent_name_prefix}-${terraform.workspace}${count.index+1}"
  pipeline_agent_pool          = var.linux_pipeline_agent_pool
  storage_type                 = var.linux_storage_type
  vm_size                      = var.linux_vm_size

  outbound_ip_address          = module.network.outbound_ip_address
  prepare_host                 = var.prepare_host
  public_access_enabled        = !var.deploy_firewall
  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = module.network.self_hosted_agents_subnet_id
  suffix                       = local.suffix
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  count                        = var.deploy_self_hosted_vms ? var.linux_self_hosted_agent_count : 0
  depends_on                   = [
    azurerm_private_endpoint.aut_blob_storage_endpoint,
    azurerm_private_endpoint.diag_blob_storage_endpoint,
    azurerm_private_endpoint.disk_access_endpoint,
    module.network
  ]
}

module self_hosted_windows_agents {
  source                       = "./modules/self-hosted-windows-agent"

  admin_cidr_ranges            = local.admin_cidr_ranges
  terraform_cidr               = local.ipprefix

  create_public_ip_address     = !var.deploy_firewall
  deploy_agent_vm_extension    = var.deploy_self_hosted_vm_agents
  deploy_non_essential_vm_extensions = var.deploy_non_essential_vm_extensions

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  diagnostics_storage_sas      = data.azurerm_storage_account_sas.diagnostics.sas
  location                     = var.location
  log_analytics_workspace_resource_id = local.log_analytics_workspace_id

  computer_name                = "windowsagent${count.index+1}"
  disk_access_name             = azurerm_disk_access.disk_access.name
  name                         = "${azurerm_resource_group.rg.name}-windows-agent${count.index+1}"
  os_offer                     = var.windows_os_offer
  os_publisher                 = var.windows_os_publisher
  os_sku                       = var.windows_os_sku
  pipeline_agent_name          = "${var.windows_pipeline_agent_name_prefix}-${terraform.workspace}${count.index+1}"
  pipeline_agent_pool          = var.windows_pipeline_agent_pool
  storage_type                 = var.windows_storage_type
  vm_size                      = var.windows_vm_size

  # outbound_ip_address          = module.network.outbound_ip_address # TODO
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags
  subnet_id                    = module.network.self_hosted_agents_subnet_id
  suffix                       = local.suffix
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