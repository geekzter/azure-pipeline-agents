locals {
  windows_pipeline_agent_name  = var.windows_pipeline_agent_name != "" ? "${lower(var.windows_pipeline_agent_name)}-${terraform.workspace}" : local.windows_vm_name
  windows_vm_name              = "${var.windows_vm_name_prefix}${substr(terraform.workspace,0,3)}${local.suffix}w"
}

resource azurerm_public_ip windows_pip {
  name                         = "${local.windows_vm_name}${count.index+1}-pip"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = local.tags
  count                        = var.windows_agent_count
}

resource azurerm_network_interface windows_nic {
  name                         = "${local.windows_vm_name}${count.index+1}-nic"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = azurerm_subnet.agent_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id       = azurerm_public_ip.windows_pip[count.index].id
  }
  enable_accelerated_networking = var.vm_accelerated_networking

  tags                         = local.tags
  count                        = var.windows_agent_count
}

resource azurerm_network_interface_security_group_association windows_nic_nsg {
  network_interface_id         = azurerm_network_interface.windows_nic[count.index].id
  network_security_group_id    = azurerm_network_security_group.nsg.id

  count                        = var.windows_agent_count
}

resource azurerm_storage_blob install_agent {
  name                         = "install_agent.ps1"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.scripts.name

  type                         = "Block"
  source                       = "../scripts/agent/install_agent.ps1"

  count                        = var.windows_agent_count > 0 ? 1 : 0
}

resource azurerm_windows_virtual_machine windows_agent {
  name                         = "${local.windows_vm_name}${count.index+1}"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  network_interface_ids        = [azurerm_network_interface.windows_nic[count.index].id]
  size                         = var.windows_vm_size
  admin_username               = var.user_name
  admin_password               = local.password

  os_disk {
    name                       = "${local.windows_vm_name}${count.index+1}-osdisk"
    caching                    = "ReadWrite"
    storage_account_type       = "Premium_LRS"
  }

  source_image_reference {
    publisher                  = var.windows_os_publisher
    offer                      = var.windows_os_offer
    sku                        = var.windows_os_sku
    version                    = "latest"
  }

  # Required for AAD Login
  identity {
    type                       = "SystemAssigned"
  }
  
  tags                         = local.tags
  count                        = var.windows_agent_count
}

resource azurerm_virtual_machine_extension pipeline_agent {
  name                         = "PipelineAgentCustomScript"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent[count.index].id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  auto_upgrade_minor_version   = true
  settings                     = <<EOF
    {
      "fileUris": [
                                 "${azurerm_storage_blob.install_agent.0.url}"
      ]
    }
  EOF

  protected_settings           = <<EOF
    { 
      "commandToExecute"       : "powershell.exe -ExecutionPolicy Unrestricted -Command \"./install_agent.ps1 -AgentName ${local.windows_pipeline_agent_name}${count.index+1} -AgentPool ${var.windows_pipeline_agent_pool} -Organization ${var.devops_org} -PAT ${var.devops_pat}\""
    } 
  EOF

  # Start VM, so we can update/destroy the extension
  provisioner local-exec {
    command                    = "az vm start --ids ${self.virtual_machine_id}"
  }
  provisioner local-exec {
    when                       = destroy
    command                    = "az vm start --ids ${self.virtual_machine_id}"
  }

  count                        = var.windows_agent_count
}