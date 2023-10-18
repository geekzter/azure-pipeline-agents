variable admin_cidr_ranges {
  type                         = list
  default                      = []
}

variable azdo_deployment_group_name {}
variable azdo_environment_name {}
variable azdo_org {}
variable azdo_pat {}
variable azdo_pipeline_agent_name {}
variable azdo_pipeline_agent_pool {}
variable azdo_pipeline_agent_version_id {}
variable azdo_project {}

variable create_public_ip_address {
  type                         = bool
}
variable deploy_agent {
  type                         = bool
}
variable deploy_files_share {
  type                         = bool
}
variable deploy_non_essential_vm_extensions {
  type                         = bool
}

variable diagnostics_smb_share {}
variable diagnostics_smb_share_mount_point {}
variable enable_public_access {
  type                         = bool
}

variable environment_variables {
    type = map
}

variable computer_name {}
variable disk_access_name {}
variable install_tools {
  type                         = bool
}
variable name {}
variable os_offer {}
variable os_publisher {}
variable os_sku {}
variable os_version {}
variable os_image_id {
  default                      = null
}

variable storage_type {}
variable vm_size {}

variable location {}
variable log_analytics_workspace_resource_id {}
variable outbound_ip_address {}
variable prepare_host {
  type                         = bool
}
variable resource_group_name {}
variable shutdown_time {}
variable subnet_id {}
variable suffix {}
variable tags {
  type                         = map
}
variable timezone {}
variable ssh_public_key {}
variable user_assigned_identity_id {}
variable user_name {}
variable user_password {}
variable vm_accelerated_networking {}
