variable admin_cidr_ranges {
    type                       = list
    default                    = []
}


variable create_public_ip_address {
  type                         = bool
}
variable deploy_agent_vm_extension {
  type                         = bool
}
variable deploy_files_share {
  type                         = bool
}
variable deploy_non_essential_vm_extensions {
  type                         = bool
}

variable devops_org {}
variable devops_pat {}

variable diagnostics_smb_share {}
variable diagnostics_storage_id {}
variable diagnostics_storage_sas {}
variable enable_public_access {
  type                         = bool
}
variable environment_variables {
  type                         = map
}

variable computer_name {}
variable disk_access_name {}
variable name {}
variable os_offer {}
variable os_publisher {}
variable os_sku {}
variable os_version {}
variable os_image_id {
  default                      = null
}

variable pipeline_agent_name {}
variable pipeline_agent_pool {}
variable pipeline_agent_version_id {}

variable storage_type {}
variable vm_size {}

variable location {}
variable log_analytics_workspace_resource_id {}
variable resource_group_name {}
variable subnet_id {}
variable suffix {}
variable tags {
  type                         = map
}
variable user_assigned_identity_id {}
variable user_name {}
variable user_password {}
variable vm_accelerated_networking {}