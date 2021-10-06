variable admin_cidr_ranges {
    type                       = list
    default                    = []
}
variable terraform_cidr {}

variable deploy_non_essential_vm_extensions {
  type                         = bool
}

variable devops_org {}
variable devops_pat {}

variable diagnostics_storage_id {}
variable diagnostics_storage_sas {}

variable computer_name {}
variable name {}
variable os_offer {}
variable os_publisher {}
variable os_sku {}
variable pipeline_agent_name {}
variable pipeline_agent_pool {}
variable storage_type {}
variable vm_size {}

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
variable user_name {}
variable user_password {}
variable vm_accelerated_networking {}