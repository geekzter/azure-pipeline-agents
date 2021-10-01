variable admin_cidr_ranges {
    type                       = list
    default                    = []
}
variable terraform_cidr {}

variable devops_org {}
variable devops_pat {}

variable diagnostics_storage_id {}
variable diagnostics_storage_sas {}

variable os_offer {}
variable os_publisher {}
variable os_sku {}
variable pipeline_agent_name {}
variable pipeline_agent_pool {}
variable storage_type {}
variable vm_name_prefix {}
variable vm_size {}

variable location {}
variable log_analytics_workspace_resource_id {}
variable outbound_ip_address {}
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

# variable windows_agent_count {}
# variable windows_os_offer {}
# variable windows_os_publisher {}
# variable windows_os_sku {}
# variable windows_pipeline_agent_name {}
# variable windows_pipeline_agent_pool {}
# variable windows_storage_type {}
# variable windows_vm_name_prefix {}
# variable windows_vm_size {}