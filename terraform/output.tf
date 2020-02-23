output ssh_commands {
  value                        = [for pip in azurerm_public_ip.pip: "ssh ${var.user_name}@${pip.ip_address}"]
}
output vm_ids {
  value                        = azurerm_virtual_machine.vm.*.id
}