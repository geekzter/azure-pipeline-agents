output password {
  sensitive                    = true
  value                        = local.password
}

output self_hosted_linux_vm_ids {
  value                        = var.linux_agent_count > 0 || var.windows_agent_count > 0 ? module.self_hosted_agents.0.linux_vm_ids : null
}
output self_hosted_windows_vm_ids {
  value                        = var.linux_agent_count > 0 || var.windows_agent_count > 0 ? module.self_hosted_agents.0.windows_vm_ids : null
}

output user_name {
  value                        = var.user_name
}