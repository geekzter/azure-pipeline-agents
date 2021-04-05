data cloudinit_config user_data {
  gzip                         = false
  base64_encode                = false

  part {
    content                    = file("${path.module}/cloud-config-userdata.yaml")
    content_type               = "text/cloud-config"
  }
}

resource azurerm_linux_virtual_machine_scale_set linux_agents {
  name                         = "${var.resource_group_name}-linux-agents"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  admin_username               = var.user_name
  custom_data                  = base64encode(data.cloudinit_config.user_data.rendered)
  instances                    = var.linux_agent_count
  overprovision                = false
  sku                          = var.linux_vm_size
  upgrade_mode                 = "Manual"

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  boot_diagnostics {
    storage_account_uri        = data.azurerm_storage_account.diagnostics.primary_blob_endpoint
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
    caching                    = "ReadOnly"
    diff_disk_settings {
      option                   = "Local"
    }
  }

  source_image_reference {
    publisher                  = var.linux_os_publisher
    offer                      = var.linux_os_offer
    sku                        = var.linux_os_sku
    version                    = "latest"
  }

  lifecycle {
    ignore_changes             = [
      instances,
    ]
  }
  tags                         = var.tags
}

# resource "azurerm_virtual_machine_scale_set_extension" "example" {
#   name                         = "example"
#   virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
#   publisher                    = "Microsoft.Azure.Extensions"
#   type                         = "CustomScript"
#   type_handler_version         = "2.0"
#   settings = jsonencode({
#     "commandToExecute" = "echo $HOSTNAME"
#   })
# }

resource azurerm_virtual_machine_scale_set_extension log_analytics {
  name                         = "OmsAgentForLinux"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "OmsAgentForLinux"
  type_handler_version         = "1.7"
  auto_upgrade_minor_version   = true
  settings                     = <<EOF
    {
      "workspaceId"            : "${data.azurerm_log_analytics_workspace.monitor.workspace_id}"
    }
  EOF
  protected_settings = <<EOF
    { 
      "workspaceKey"           : "${data.azurerm_log_analytics_workspace.monitor.primary_shared_key}"
    } 
  EOF
}

resource azurerm_virtual_machine_scale_set_extension dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentLinux"
  type_handler_version         = "9.5"
  auto_upgrade_minor_version   = true
  settings                     = <<EOF
    {
      "workspaceId"            : "${data.azurerm_log_analytics_workspace.monitor.id}"
    }
  EOF

  protected_settings = <<EOF
    { 
      "workspaceKey"           : "${data.azurerm_log_analytics_workspace.monitor.primary_shared_key}"
    } 
  EOF
}
resource azurerm_virtual_machine_scale_set_extension watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentLinux"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true
}

# resource azurerm_monitor_diagnostic_setting vm {
#   name                         = "${azurerm_linux_virtual_machine_scale_set.linux_agents.name}-diagnostics"
#   target_resource_id           = azurerm_linux_virtual_machine_scale_set.linux_agents.id
#   log_analytics_workspace_id   = data.azurerm_log_analytics_workspace.monitor.id

#   metric {
#     category                   = "AllMetrics"

#     retention_policy {
#       enabled                  = false
#     }
#   }
# }