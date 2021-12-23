variable address_space {
  # Use Class C segment, to minimize conflict with networks provisioned from pipelines
  default                      = "192.168.0.0/24"
}

variable admin_ip_ranges {
  default                      = []
}

variable configure_cidr_allow_rules {
  default                      = false
  type                         = bool
}
variable configure_crl_oscp_rules {
  default                      = true
  type                         = bool
}
variable configure_wildcard_allow_rules {
  default                      = true
  type                         = bool
}
variable create_contributor_service_principal {
  description                  = "Create Service Principal that can be used for a Service Connection"
  default                      = false
  type                         = bool
}
variable deploy_bastion {
  description                  = "Deploys managed bastion host"
  default                      = true
  type                         = bool
}
variable deploy_firewall {
  description                  = "Deploys NAT Gateway if set to false"
  default                      = false
  type                         = bool
}
variable deploy_non_essential_vm_extensions {
  description                  = "Whether to deploy optional VM extensions"
  default                      = true
  type                         = bool
}
variable deploy_scale_set {
  default                      = true
  type                         = bool
}
variable deploy_self_hosted_vms {
  default                      = false
  type                         = bool
}
variable deploy_self_hosted_vm_agents {
  default                      = true
  type                         = bool
}

variable destroy_wait_minutes {
  default                      = 2
  type                         = number
}
variable devops_org {
  description                  = "The Azure DevOps org to join self-hosted agents to (default pool: 'Default', see linux_pipeline_agent_pool/windows_pipeline_agent_pool)"
}
variable devops_pat {
  description                  = "A Personal Access Token to access the Azure DevOps organization"
}

variable dns_host_suffix {
  default                      = "mycicd"
}

variable linux_os_offer {
  default                      = "UbuntuServer"
}
variable linux_os_publisher {
  default                      = "Canonical"
}
variable linux_os_sku {
  default                      = "18.04-LTS"
}
variable linux_os_version {
  default                      = "latest"
}
variable linux_pipeline_agent_name_prefix {
  default                      = "ubuntu-agent"
}
variable linux_pipeline_agent_pool {
  default                      = "Default"
}
variable linux_scale_set_agent_count {
  default                      = 2
  type                         = number
}
variable linux_self_hosted_agent_count {
  default                      = 1
  type                         = number
}
variable linux_storage_type {
  default                      = "Standard_LRS"
}
variable linux_vm_size {
  default                      = "Standard_D2s_v3"
}

variable location {
  default                      = "westeurope"
}

variable log_analytics_workspace_id {
  description                  = "Specify a pre-existing Log Analytics workspace. The workspace needs to have the Security, SecurityCenterFree, ServiceMap, Updates, VMInsights solutions provisioned"
  default                      = ""
}

variable prepare_host {
  type                         = bool
  default                      = true
}

variable resource_suffix {
  description                  = "The suffix to put at the of resource names created"
  default                      = "" # Empty string triggers a random suffix
}

variable run_id {
  description                  = "The ID that identifies the pipeline / workflow that invoked Terraform"
  default                      = ""
}

variable script_wrapper_check {
  description                  = "Set to true in a .auto.tfvars file to force Terraform to check whether it's run from deploy.ps1"
  type                         = bool
  default                      = false
}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map

  default = {
    shutdown                   = "false"
  }  
} 

variable user_name {
  default                      = "devopsadmin"
}

variable vm_accelerated_networking {
  default                      = false
}

variable windows_agent_count {
  default                      = 2
  type                         = number
}
# az vm image list-skus -l westeurope -f "visualstudio2019latest" -p "microsoftvisualstudio" -o table
variable windows_os_offer {
  default                      = "visualstudio2022"
}
variable windows_os_publisher {
  default                      = "microsoftvisualstudio"
}
variable windows_os_sku {
  default                      = "vs-2022-comm-latest-ws2022"
}
variable windows_os_version {
  default                      = "latest"
}
variable windows_pipeline_agent_name_prefix {
  default                      = "windows-agent"
}
variable windows_pipeline_agent_pool {
  default                      = "Default"
}
variable windows_scale_set_agent_count {
  default                      = 2
  type                         = number
}
variable windows_self_hosted_agent_count {
  default                      = 1
  type                         = number
}
variable windows_storage_type {
  default                      = "Standard_LRS"
}
variable windows_vm_size {
  default                      = "Standard_D4s_v3"
}