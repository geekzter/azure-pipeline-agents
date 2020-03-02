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
  count                        = var.provision_linux ? var.linux_agent_count : 0
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
  count                        = var.provision_linux ? var.linux_agent_count : 0
}

resource azurerm_network_interface_security_group_association linux_nic_nsg {
  network_interface_id         = azurerm_network_interface.linux_nic[count.index].id
  network_security_group_id    = azurerm_network_security_group.nsg.id

  count                        = var.provision_linux ? var.linux_agent_count : 0
}

resource azurerm_virtual_machine linux_agent {
  name                         = "${local.linux_vm_name}${count.index+1}"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
  network_interface_ids        = [azurerm_network_interface.linux_nic[count.index].id]
  vm_size                      = var.linux_vm_size

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher                  = var.linux_os_publisher
    offer                      = var.linux_os_offer
    sku                        = var.linux_os_sku
    version                    = "latest"
  }
  storage_os_disk {
    name                       = "${local.linux_vm_name}${count.index+1}-osdisk"
    caching                    = "ReadWrite"
    create_option              = "FromImage"
    managed_disk_type          = "Premium_LRS"
  }
  os_profile {
    computer_name              = "${local.linux_vm_name}${count.index+1}"
    admin_username             = var.user_name
    # The password is only used here in Terraform but not exported. 
    admin_password             = local.password
  }
  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      key_data                 = file(var.ssh_public_key)
      path                     = "/home/${var.user_name}/.ssh/authorized_keys"
    }
  }

  tags                         = local.tags
  count                        = var.provision_linux ? var.linux_agent_count : 0
  depends_on                   = [azurerm_network_interface_security_group_association.linux_nic_nsg]
}

resource null_resource linux_bootstrap {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    # Start VM, so we can execute script through SSH
    command                    = "az vm start --ids ${azurerm_virtual_machine.linux_agent[count.index].id}"
  }

  # Bootstrap using https://github.com/geekzter/bootstrap-os/tree/master/linux
  provisioner remote-exec {
    inline                     = [
      "sudo apt-get update -y",
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

  count                        = var.provision_linux ? var.linux_agent_count : 0
  depends_on                   = [azurerm_virtual_machine.linux_agent,azurerm_network_interface_security_group_association.linux_nic_nsg]
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
      "sudo apt-get update -y",
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

  count                        = var.provision_linux ? var.linux_agent_count : 0
  depends_on                   = [null_resource.linux_bootstrap,azurerm_network_interface_security_group_association.linux_nic_nsg]
}