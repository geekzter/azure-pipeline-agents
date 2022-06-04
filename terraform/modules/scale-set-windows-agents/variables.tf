variable deploy_files_share {
  type                         = bool
}
variable deploy_non_essential_vm_extensions {
  type                         = bool
}

variable diagnostics_smb_share {}
variable environment_variables {
    type = map
}

variable windows_agent_count {}
variable windows_os_offer {}
variable windows_os_publisher {}
variable windows_os_sku {}
variable windows_os_version {}
variable windows_os_image_id {
  default                      = null
}
variable windows_storage_type {}
variable windows_vm_name_prefix {}
variable windows_vm_size {}

variable location {}
variable log_analytics_workspace_resource_id {}
variable outbound_ip_address {}
variable prepare_host {
  type                         = bool
}
variable resource_group_name {}
variable subnet_id {}
variable suffix {}
variable tags {
    type = map
}
variable user_assigned_identity_id {}
variable user_name {}
variable user_password {}
variable vm_accelerated_networking {}

