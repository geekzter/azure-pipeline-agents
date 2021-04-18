module scale_set_agents {
  source                       = "./modules/scale-set-agents"

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  location                     = var.location
  log_analytics_workspace_resource_id = azurerm_log_analytics_workspace.monitor.id

  linux_agent_count            = var.linux_agent_count
  linux_pipeline_agent_name    = var.linux_pipeline_agent_name
  linux_pipeline_agent_pool    = var.linux_pipeline_agent_pool
  linux_os_offer               = var.linux_os_offer
  linux_os_publisher           = var.linux_os_publisher
  linux_os_sku                 = var.linux_os_sku
  linux_storage_type           = var.linux_storage_type
  linux_vm_name_prefix         = var.linux_vm_name_prefix
  linux_vm_size                = var.linux_vm_size

  scripts_container_id         = azurerm_storage_container.scripts.id

  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = azurerm_subnet.agent_subnet.id
  suffix                       = local.suffix
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  # windows_agent_count          = var.windows_agent_count
  # windows_pipeline_agent_name  = var.windows_pipeline_agent_name
  # windows_pipeline_agent_pool  = var.windows_pipeline_agent_pool
  # windows_os_offer             = var.windows_os_offer
  # windows_os_publisher         = var.windows_os_publisher
  # windows_os_sku               = var.windows_os_sku
  # windows_storage_type         = var.windows_storage_type
  # windows_vm_name_prefix       = var.windows_vm_name_prefix
  # windows_vm_size              = var.windows_vm_size

  count                        = var.use_scale_set ? 1 : 0
}

module self_hosted_agents {
  source                       = "./modules/self-hosted-agents"

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  diagnostics_storage_id       = azurerm_storage_account.diagnostics.id
  location                     = var.location
  log_analytics_workspace_resource_id = azurerm_log_analytics_workspace.monitor.id

  linux_agent_count            = var.linux_agent_count
  linux_pipeline_agent_name    = var.linux_pipeline_agent_name
  linux_pipeline_agent_pool    = var.linux_pipeline_agent_pool
  linux_os_offer               = var.linux_os_offer
  linux_os_publisher           = var.linux_os_publisher
  linux_os_sku                 = var.linux_os_sku
  linux_storage_type           = var.linux_storage_type
  linux_vm_name_prefix         = var.linux_vm_name_prefix
  linux_vm_size                = var.linux_vm_size

  scripts_container_id         = azurerm_storage_container.scripts.id

  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = azurerm_subnet.agent_subnet.id
  suffix                       = local.suffix
  user_name                    = var.user_name
  user_password                = local.password
  vm_accelerated_networking    = var.vm_accelerated_networking

  windows_agent_count          = var.windows_agent_count
  windows_pipeline_agent_name  = var.windows_pipeline_agent_name
  windows_pipeline_agent_pool  = var.windows_pipeline_agent_pool
  windows_os_offer             = var.windows_os_offer
  windows_os_publisher         = var.windows_os_publisher
  windows_os_sku               = var.windows_os_sku
  windows_storage_type         = var.windows_storage_type
  windows_vm_name_prefix       = var.windows_vm_name_prefix
  windows_vm_size              = var.windows_vm_size

  count                        = var.use_self_hosted ? 1 : 0
}