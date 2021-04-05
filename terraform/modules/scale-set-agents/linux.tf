resource azurerm_linux_virtual_machine_scale_set linux_agents {
  name                         = "${var.resource_group_name}-linux-agents"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = var.linux_vm_size
  instances                    = var.linux_agent_count
  admin_username               = var.user_name

  overprovision                = false
  upgrade_mode                 = "Manual"

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  network_interface {
    name                       = "${var.resource_group_name}-linux-agents-nic"
    primary                    = true

    ip_configuration {
      name                     = "ipconfig"
      primary                  = true
      subnet_id                = var.subnet_id

      # public_ip_address {
      #   name                   = "${var.resource_group_name}-linux-agents-pip"
      # }
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

  tags                         = var.tags
}

# resource "azurerm_virtual_machine_scale_set_extension" "example" {
#   name                         = "example"
#   virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.example.id
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

resource azurerm_virtual_machine_scale_set_extension vm_dependency_monitor {
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
resource azurerm_virtual_machine_scale_set_extension vm_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentLinux"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true
}