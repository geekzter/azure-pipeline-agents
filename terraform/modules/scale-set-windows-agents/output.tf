output host_configuration_script {
  sensitive                    = true
  value                        = local.host_configuration_script
}

output virtual_machine_scale_set_id {
  value                         = azurerm_windows_virtual_machine_scale_set.windows_agents.id
}
output virtual_machine_scale_set_name {
  value                         = azurerm_windows_virtual_machine_scale_set.windows_agents.name
}