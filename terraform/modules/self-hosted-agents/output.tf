output linux_vm_ids {
  value                        = azurerm_linux_virtual_machine.linux_agent.*.id
}
output windows_vm_ids {
  value                        = azurerm_windows_virtual_machine.windows_agent.*.id
}