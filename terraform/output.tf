output rdp_commands {
  value                        = [for pip in azurerm_public_ip.windows_pip: "mstsc /v:${pip.ip_address}"]
}
output ssh_commands {
  value                        = [for pip in azurerm_public_ip.linux_pip: "ssh ${var.user_name}@${pip.ip_address}"]
}
output linux_vm_ids {
  value                        = azurerm_virtual_machine.linux_agent.*.id
}
output windows_vm_ids {
  value                        = azurerm_windows_virtual_machine.windows_agent.*.id
}
output vm_ids {
  value                        = concat(azurerm_virtual_machine.linux_agent.*.id,azurerm_windows_virtual_machine.windows_agent.*.id)
}
output username {
  value                        = var.user_name
}
output password {
  value                        = local.password
}