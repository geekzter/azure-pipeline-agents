output ssh_command {
  value       = "ssh ${var.user_name}@${azurerm_public_ip.pip.ip_address}"
}