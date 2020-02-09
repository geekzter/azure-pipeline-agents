output ssh_command {
  value       = "ssh ${var.user_name}@${azurerm_public_ip.pip.ip_address}"
}
output vm_id {
  value       = azurerm_virtual_machine.vm.id
}