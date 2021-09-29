output linux_cloud_config {
  sensitive                    = true
  value                        = data.cloudinit_config.user_data.rendered
}
output linux_vm_ids {
  value                        = azurerm_linux_virtual_machine.linux_agent.id
}