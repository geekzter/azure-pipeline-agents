module self_hosted_agents {
  source                       = "./modules/self-hosted-agents"

  devops_org                   = var.devops_org
  devops_pat                   = var.devops_pat

  user_name                    = var.user_name
  password                     = local.password
  location                     = var.location

  linux_agent_count            = var.linux_agent_count
  linux_pipeline_agent_name    = var.linux_pipeline_agent_name
  linux_pipeline_agent_pool    = var.linux_pipeline_agent_pool
  linux_os_offer               = var.linux_os_offer
  linux_os_publisher           = var.linux_os_publisher
  linux_os_sku                 = var.linux_os_sku
  linux_vm_name_prefix         = var.linux_vm_name_prefix
  linux_vm_size                = var.linux_vm_size

  scripts_container_id         = azurerm_storage_container.scripts.id

  resource_group_name          = azurerm_resource_group.rg.name
  ssh_public_key               = var.ssh_public_key
  tags                         = local.tags
  subnet_id                    = azurerm_subnet.agent_subnet.id
  suffix                       = local.suffix
  vm_accelerated_networking    = var.vm_accelerated_networking

  windows_agent_count          = var.windows_agent_count
  windows_pipeline_agent_name  = var.windows_pipeline_agent_name
  windows_pipeline_agent_pool  = var.windows_pipeline_agent_pool
  windows_os_offer             = var.windows_os_offer
  windows_os_publisher         = var.windows_os_publisher
  windows_os_sku               = var.windows_os_sku
  windows_vm_name_prefix       = var.windows_vm_name_prefix
  windows_vm_size              = var.windows_vm_size

  count                        = var.linux_agent_count > 0 || var.windows_agent_count > 0 ? 1 : 0
}