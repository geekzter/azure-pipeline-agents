data cloudinit_config user_data {
  gzip                         = false
  base64_encode                = false

  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-userdata.yaml",
    {
      outbound_ip              = var.outbound_ip_address
      subnet_id                = var.subnet_id
      virtual_network_id       = local.virtual_network_id
    })
    content_type               = "text/cloud-config"
  }
}

resource azurerm_image vhd {
  name                         = "${var.resource_group_name}-linux-agents-image"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  os_disk {
    os_type                    = "Linux"
    os_state                   = "Generalized"
    blob_uri                   = var.linux_os_vhd_url
    size_gb                    = 100
  }

  count                        = (var.linux_os_vhd_url != null && var.linux_os_vhd_url != "") ? 1 : 0
}

resource azurerm_linux_virtual_machine_scale_set linux_agents {
  name                         = "${var.resource_group_name}-linux-agents"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  admin_username               = var.user_name
  custom_data                  = var.prepare_host ? base64encode(data.cloudinit_config.user_data.rendered) : null
  instances                    = var.linux_agent_count
  overprovision                = false
  sku                          = var.linux_vm_size
  upgrade_mode                 = "Manual"

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  boot_diagnostics {
    storage_account_uri        = "${data.azurerm_storage_account.diagnostics.primary_blob_endpoint}${var.diagnostics_storage_sas}"
  }

  network_interface {
    name                       = "${var.resource_group_name}-linux-agents-nic"
    primary                    = true

    ip_configuration {
      name                     = "ipconfig"
      primary                  = true
      subnet_id                = var.subnet_id
    }
  }

  os_disk {
    storage_account_type       = var.linux_storage_type
    caching                    = "ReadWrite"
  }

  source_image_id              = (var.linux_os_vhd_url != null && var.linux_os_vhd_url != "") ? azurerm_image.vhd.0.id : null

  dynamic "source_image_reference" {
    for_each = range((var.linux_os_vhd_url != null && var.linux_os_vhd_url != "") ? 0 : 1) 
    content {
      publisher                = var.linux_os_publisher
      offer                    = var.linux_os_offer
      sku                      = var.linux_os_sku
      version                  = var.linux_os_version
    }
  }    

  lifecycle {
    ignore_changes             = [
      instances,
    ]
  }
  tags                         = var.tags
}

resource azurerm_virtual_machine_scale_set_extension cloud_config_status {
  name                         = "CloudConfigStatusScript"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  auto_upgrade_minor_version   = true
  settings                     = jsonencode({
    "commandToExecute"         = "/usr/bin/cloud-init status --long --wait ; systemctl status cloud-final.service --full --no-pager --wait"
  })
}

resource azurerm_virtual_machine_scale_set_extension purge_log_analytics {
  name                         = "PurgeOmsAgentScript"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  auto_upgrade_minor_version   = true
  settings                     = jsonencode({
    "commandToExecute"         = "[ -f /opt/microsoft/omsagent/bin/purge_omsagent.sh ] && sudo /opt/microsoft/omsagent/bin/purge_omsagent.sh ; echo done"
  })

  provision_after_extensions   = [
    # Wait for cloud-init to complete before provisioning extensions
    azurerm_virtual_machine_scale_set_extension.cloud_config_status.name
  ]

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}

resource azurerm_virtual_machine_scale_set_extension linux_log_analytics {
  name                         = "OmsAgentForLinux"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "OmsAgentForLinux"
  type_handler_version         = "1.7"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  provision_after_extensions   = [
    # Wait for cloud-init to complete before provisioning extensions
    azurerm_virtual_machine_scale_set_extension.cloud_config_status.name,
    azurerm_virtual_machine_scale_set_extension.purge_log_analytics.0.name
  ]

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}
resource azurerm_virtual_machine_scale_set_extension diagnostics {
  name                         = "LinuxDiagnostic"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.Azure.Diagnostics"
  type                         = "LinuxDiagnostic"
  type_handler_version         = "3.0"
  auto_upgrade_minor_version   = true

  settings                     = templatefile("${path.module}/linuxdiagnostics.json", { 
    storage_account_name       = data.azurerm_storage_account.diagnostics.name, 
    virtual_machine_id         = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  })
  protected_settings           = jsonencode({
    "storageAccountName"       = data.azurerm_storage_account.diagnostics.name
    "storageAccountSasToken"   = trimprefix(var.diagnostics_storage_sas,"?")
  })

  depends_on                   = [
    azurerm_virtual_machine_scale_set_extension.linux_log_analytics
  ]

  provision_after_extensions   = [
    # Wait for cloud-init to complete before provisioning extensions
    azurerm_virtual_machine_scale_set_extension.cloud_config_status.name,
    azurerm_virtual_machine_scale_set_extension.linux_log_analytics.0.name
  ]

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}
resource azurerm_virtual_machine_scale_set_extension linux_dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentLinux"
  type_handler_version         = "9.5"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  provision_after_extensions   = [
    # Wait for cloud-init to complete before provisioning extensions
    azurerm_virtual_machine_scale_set_extension.cloud_config_status.name
  ]

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}
resource azurerm_virtual_machine_scale_set_extension linux_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentLinux"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  provision_after_extensions   = [
    # Wait for cloud-init to complete before provisioning extensions
    azurerm_virtual_machine_scale_set_extension.cloud_config_status.name
  ]

  count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting linux_agents {
  name                         = "${azurerm_linux_virtual_machine_scale_set.linux_agents.name}-logs"
  target_resource_id           = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
} 