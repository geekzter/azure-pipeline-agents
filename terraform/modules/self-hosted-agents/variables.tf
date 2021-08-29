variable admin_cidr_ranges {
    type                       = list
    default                    = []
}
variable terraform_cidr {}

variable devops_org {}
variable devops_pat {}

variable diagnostics_storage_id {}
variable diagnostics_storage_sas {}

variable linux_agent_count {}
variable linux_os_offer {}
variable linux_os_publisher {}
variable linux_os_sku {}
variable linux_pipeline_agent_name {}
variable linux_pipeline_agent_pool {}
variable linux_storage_type {}
variable linux_vm_name_prefix {}
variable linux_vm_size {}

variable location {}
variable log_analytics_workspace_resource_id {}
variable public_access_enabled {
    type    = bool
    default = false
}
variable resource_group_name {}
variable subnet_id {}
variable suffix {}
variable tags {
    type    = map
}
variable ssh_public_key {}
variable user_name {}
variable user_password {}
variable vm_accelerated_networking {}

variable windows_agent_count {}
variable windows_os_offer {}
variable windows_os_publisher {}
variable windows_os_sku {}
variable windows_pipeline_agent_name {}
variable windows_pipeline_agent_pool {}
variable windows_storage_type {}
variable windows_vm_name_prefix {}
variable windows_vm_size {}