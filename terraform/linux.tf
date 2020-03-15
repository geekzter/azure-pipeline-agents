locals {
  linux_pipeline_agent_name    = var.linux_pipeline_agent_name != "" ? "${lower(var.linux_pipeline_agent_name)}-${terraform.workspace}" : local.linux_vm_name
  linux_vm_name                = "${var.linux_vm_name_prefix}-${terraform.workspace}-${local.suffix}"
}

resource azurerm_public_ip linux_pip {
  name                         = "${local.linux_vm_name}${count.index+1}-pip"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = local.tags
  count                        = var.linux_agent_count
}

resource azurerm_network_interface linux_nic {
  name                         = "${local.linux_vm_name}${count.index+1}-nic"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = data.azurerm_subnet.pipeline_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id       = azurerm_public_ip.linux_pip[count.index].id
  }
  enable_accelerated_networking = var.vm_accelerated_networking

  tags                         = local.tags
  count                        = var.linux_agent_count
}

resource azurerm_network_interface_security_group_association linux_nic_nsg {
  network_interface_id         = azurerm_network_interface.linux_nic[count.index].id
  network_security_group_id    = azurerm_network_security_group.nsg.id

  count                        = var.linux_agent_count
}

resource azurerm_linux_virtual_machine linux_agent {
  name                         = "${local.linux_vm_name}${count.index+1}"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
  size                         = var.linux_vm_size
  admin_username               = var.user_name
  admin_password               = local.password
  disable_password_authentication = false
  network_interface_ids        = [azurerm_network_interface.linux_nic[count.index].id]

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  os_disk {
    caching                    = "ReadWrite"
    storage_account_type       = "Premium_LRS"
  }

  source_image_reference {
    publisher                  = var.linux_os_publisher
    offer                      = var.linux_os_offer
    sku                        = var.linux_os_sku
    version                    = "latest"
  }

  tags                         = local.tags
  count                        = var.linux_agent_count
  depends_on                   = [azurerm_network_interface_security_group_association.linux_nic_nsg]
}

resource null_resource linux_bootstrap {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    # Start VM, so we can execute script through SSH
    command                    = "az vm start --ids ${azurerm_linux_virtual_machine.linux_agent[count.index].id}"
  }

  # Bootstrap using https://github.com/geekzter/bootstrap-os/tree/master/linux
  provisioner remote-exec {
    inline                     = [
      "echo ${local.password} | sudo -S apt-get update -y",
      "sudo apt-get -y install curl", 
      "curl -sk https://raw.githubusercontent.com/geekzter/bootstrap-os/master/linux/bootstrap_linux.sh | bash"
    ]

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = local.password
      host                     = azurerm_public_ip.linux_pip[count.index].ip_address
    }
  }

  count                        = var.linux_agent_count
  depends_on                   = [azurerm_linux_virtual_machine.linux_agent,azurerm_network_interface_security_group_association.linux_nic_nsg]
}

resource null_resource linux_pipeline_agent {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner "file" {
    source                     = "../scripts/agent/install_agent.sh"
    destination                = "~/install_agent.sh"

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = local.password
      host                     = azurerm_public_ip.linux_pip[count.index].ip_address
    }
  }

  provisioner remote-exec {
    inline                     = [
      "echo ${local.password} | sudo -S apt-get update -y",
      # We need dos2unix (depending on where we're uploading from) before we run the script, so install script pre-requisites inline here
      "sudo apt-get -y install curl dos2unix jq sed", 
      "dos2unix ~/install_agent.sh",
      "chmod +x ~/install_agent.sh",
      "~/install_agent.sh --agent-name ${local.linux_pipeline_agent_name}${count.index+1} --agent-pool ${var.linux_pipeline_agent_pool} --org ${var.devops_org} --pat ${var.devops_pat}"
    ]

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = local.password
      host                     = azurerm_public_ip.linux_pip[count.index].ip_address
    }
  }

  count                        = var.linux_agent_count
  depends_on                   = [null_resource.linux_bootstrap,azurerm_network_interface_security_group_association.linux_nic_nsg]
}