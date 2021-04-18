locals {
  scripts_container_name       = element(split("/",var.scripts_container_id),length(split("/",var.scripts_container_id))-1)
  scripts_storage_name         = element(split(".",element(split("/",var.scripts_container_id),length(split("/",var.scripts_container_id))-2)),0)
  virtual_network_id           = join("/",slice(split("/",var.subnet_id),0,length(split("/",var.subnet_id))-2))
}

resource azurerm_network_security_group nsg {
  name                         = "${local.linux_vm_name}-nsg"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  security_rule {
    name                       = "InboundRDP"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "InboundSSH"
    priority                   = 202
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags                         = var.tags
}