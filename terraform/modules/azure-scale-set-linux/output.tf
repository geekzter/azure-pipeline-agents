output cloud_config {
  sensitive                    = true
  value                        = var.prepare_host ? data.cloudinit_config.user_data.0.rendered : null
}

output virtual_machine_scale_set_id {
  value                         = azurerm_linux_virtual_machine_scale_set.linux_agents.id
}
output virtual_machine_scale_set_name {
  value                         = azurerm_linux_virtual_machine_scale_set.linux_agents.name
}