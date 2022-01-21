variable deploy_non_essential_vm_extensions {
  type                         = bool
}

variable devops_org {}
variable devops_pat {}

variable diagnostics_storage_id {}
variable diagnostics_storage_sas {}

variable linux_agent_count {}
variable linux_os_offer {}
variable linux_os_publisher {}
variable linux_os_sku {}
variable linux_os_version {}
variable linux_os_image_id {
  default                      = null
}

variable linux_storage_type {}
variable linux_vm_name_prefix {}
variable linux_vm_size {}

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
variable ssh_public_key {}
variable user_name {}
variable user_password {}
variable vm_accelerated_networking {}
