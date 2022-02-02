data cloudinit_config user_data {
  gzip                         = false
  base64_encode                = false

  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-post-generation.yaml",
    {
      user_name                = var.user_name
    })
    content_type               = "text/cloud-config"
    merge_type                 = "list(append)+dict(recurse_array)+str()"
  }
  
  dynamic "part" {
    for_each = range(var.install_tools ? 1 : 0)
    content {
      content                  = templatefile("${path.root}/../cloudinit/cloud-config-tools.yaml",
      {
        outbound_ip            = var.outbound_ip_address
        subnet_id              = var.subnet_id
        virtual_network_id     = local.virtual_network_id
      })
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }  

  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-userdata.yaml",
    {
      outbound_ip              = var.outbound_ip_address
      subnet_id                = var.subnet_id
      user_name                = var.user_name
      virtual_network_id       = local.virtual_network_id
    })
    content_type               = "text/cloud-config"
    merge_type                 = "list(append)+dict(recurse_array)+str()"
  }

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

  source_image_id              = var.linux_os_image_id

  dynamic "source_image_reference" {
    for_each = range(var.linux_os_image_id == null || var.linux_os_image_id == "" ? 1 : 0) 
    content {
      publisher                = var.linux_os_publisher
      offer                    = var.linux_os_offer
      sku                      = var.linux_os_sku
      version                  = var.linux_os_version
    }
  }  

  extension {
    name                       = "CloudConfigStatusScript"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.0"
    auto_upgrade_minor_version = true
    settings                   = jsonencode({
      "commandToExecute"       = "/usr/bin/cloud-init status --long --wait ; systemctl status cloud-final.service --full --no-pager --wait"
    })
  }

  dynamic "extension" {
    for_each = range(var.deploy_non_essential_vm_extensions ? 1 : 0)
    content {
      name                     = "OmsAgentForLinux"
      publisher                = "Microsoft.EnterpriseCloud.Monitoring"
      type                     = "OmsAgentForLinux"
      type_handler_version     = "1.7"
      auto_upgrade_minor_version= true

      settings                 = jsonencode({
        "workspaceId"          = data.azurerm_log_analytics_workspace.monitor.workspace_id
      })
      protected_settings       = jsonencode({
        "workspaceKey"         = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
      })

      provision_after_extensions= [
        # Wait for cloud-init to complete before provisioning extensions
        "CloudConfigStatusScript"
      ]
    }
  }  

  dynamic "extension" {
    for_each = range(var.deploy_non_essential_vm_extensions ? 1 : 0)
    content {
      name                     = "DAExtension"
      publisher                = "Microsoft.Azure.Monitoring.DependencyAgent"
      type                     = "DependencyAgentLinux"
      type_handler_version     = "9.5"
      auto_upgrade_minor_version= true

      settings                 = jsonencode({
        "workspaceId"          = data.azurerm_log_analytics_workspace.monitor.workspace_id
      })
      protected_settings       = jsonencode({
        "workspaceKey"         = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
      })

      provision_after_extensions = [
        "CloudConfigStatusScript",
      ]
    }
  } 
  dynamic "extension" {
    for_each = range(var.deploy_non_essential_vm_extensions ? 1 : 0)
    content {
      name                     = "AzureNetworkWatcherExtension"
      publisher                = "Microsoft.Azure.NetworkWatcher"
      type                     = "NetworkWatcherAgentLinux"
      type_handler_version     = "1.4"
      auto_upgrade_minor_version= true

      provision_after_extensions= [
        "CloudConfigStatusScript",
      ]
    }
  } 
  lifecycle {
    ignore_changes             = [
      instances,
    ]
  }
  tags                         = var.tags
}

# # TODO: Replace with Azure Monitoring Agent, does not work with python 3
# # https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/diagnostics-linux?tabs=azcli#python-requirement
# resource azurerm_virtual_machine_scale_set_extension diagnostics {
#   name                         = "LinuxDiagnostic"
#   virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.linux_agents.id
#   publisher                    = "Microsoft.Azure.Diagnostics"
#   type                         = "LinuxDiagnostic"
#   type_handler_version         = "3.0"
#   auto_upgrade_minor_version   = true

#   settings                     = templatefile("${path.module}/linuxdiagnostics.json", { 
#     storage_account_name       = data.azurerm_storage_account.diagnostics.name, 
#     virtual_machine_id         = azurerm_linux_virtual_machine_scale_set.linux_agents.id
#   })
#   protected_settings           = jsonencode({
#     "storageAccountName"       = data.azurerm_storage_account.diagnostics.name
#     "storageAccountSasToken"   = trimprefix(var.diagnostics_storage_sas,"?")
#   })

#   provision_after_extensions   = [
#     "CloudConfigStatusScript",
#     "OmsAgentForLinux"
#   ]

#   count                        = var.deploy_non_essential_vm_extensions ? 1 : 0
# }

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