output cloud_config {
  sensitive                    = true
  value                        = data.cloudinit_config.user_data.rendered
}
output vm_ids {
  value                        = azurerm_linux_virtual_machine.linux_agent.id
}