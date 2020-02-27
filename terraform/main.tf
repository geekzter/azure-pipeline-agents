# Data sources
data azurerm_resource_group pipeline_resource_group {
  name                         = var.pipeline_resource_group
}

data azurerm_virtual_network pipeline_network {
  name                         = var.pipeline_network
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
}

data azurerm_subnet pipeline_subnet {
  name                         = var.pipeline_subnet
  virtual_network_name         = data.azurerm_virtual_network.pipeline_network.name
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
}

# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  number                       = false
  special                      = false
}

# Random password generator
resource random_string password {
  length                       = 12
  upper                        = true
  lower                        = true
  number                       = true
  special                      = true
# override_special             = "!@#$%&*()-_=+[]{}<>:?" # default
# Avoid characters that may cause shell scripts to break
  override_special             = "." 
}
locals {
  password                     = ".Az9${random_string.password.result}"
  pipeline_agent_name          = var.pipeline_agent_name != "" ? "${lower(var.pipeline_agent_name)}-${terraform.workspace}" : local.vm_name
  suffix                       = random_string.suffix.result
  tags                         = map(
      "environment",             "pipelines",
      "suffix",                  local.suffix,
      "workspace",               terraform.workspace
  )
  vm_name                      = "${var.vm_name_prefix}-${terraform.workspace}-${local.suffix}"
}

resource azurerm_public_ip pip {
  name                         = "${local.vm_name}${count.index+1}-pip"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
  allocation_method            = "Static"

  tags                         = local.tags

  count                        = var.agent_count
}

resource azurerm_network_interface nic {
  name                         = "${local.vm_name}${count.index+1}-nic"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = data.azurerm_subnet.pipeline_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id       = azurerm_public_ip.pip[count.index].id
  }
  tags                         = local.tags

  count                        = var.agent_count
}

resource azurerm_virtual_machine vm {
  name                         = "${local.vm_name}${count.index+1}"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
  network_interface_ids        = [azurerm_network_interface.nic[count.index].id]
  vm_size                      = var.vm_size

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher                  = "Canonical"
    offer                      = "UbuntuServer"
    sku                        = "18.04-LTS"
    version                    = "latest"
  }
  storage_os_disk {
    name                       = "${local.vm_name}${count.index+1}-osdisk"
    caching                    = "ReadWrite"
    create_option              = "FromImage"
    managed_disk_type          = "Premium_LRS"
  }
  os_profile {
    computer_name              = "${local.vm_name}${count.index+1}"
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

  count                        = var.agent_count
}

resource null_resource bootstrap_os {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    # Start VM, so we can execute script through SSH
    command                    = "az vm start --ids ${azurerm_virtual_machine.vm[count.index].id}"
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
      host                     = azurerm_public_ip.pip[count.index].ip_address
    }
  }

  count                        = var.agent_count
  depends_on                   = [azurerm_virtual_machine.vm]
}

resource null_resource pipeline_agent {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner "file" {
    source      = "../scripts/agent/install_agent.sh"
    destination = "~/install_agent.sh"

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = local.password
      host                     = azurerm_public_ip.pip[count.index].ip_address
    }
  }

  provisioner remote-exec {
    inline                     = [
      "sudo apt-get update -y",
      # We need dos2unix (depending on where we're uploading from) before we run the script, so install script pre-requisites inline here
      "sudo apt-get -y install curl dos2unix jq sed", 
      "dos2unix ~/install_agent.sh",
      "chmod +x ~/install_agent.sh",
      "~/install_agent.sh --agent-name ${local.pipeline_agent_name}${count.index+1} --agent-pool ${var.pipeline_agent_pool} --org ${var.devops_org} --pat ${var.devops_pat}"
    ]

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = local.password
      host                     = azurerm_public_ip.pip[count.index].ip_address
    }
  }

  count                        = var.agent_count
  depends_on                   = [null_resource.bootstrap_os]
}
