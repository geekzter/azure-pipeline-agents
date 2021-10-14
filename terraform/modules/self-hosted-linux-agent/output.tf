output cloud_config {
  sensitive                    = true
  value                        = var.deploy_agent_vm_extension || var.prepare_host ? base64encode(data.cloudinit_config.user_data.0.rendered) : null
}
output vm_id {
  value                        = azurerm_linux_virtual_machine.linux_agent.id
}