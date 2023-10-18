variable address_space {
  default                      = "10.201.0.0/22"
}

variable admin_ip_ranges {
  default                      = []
  type                         = list
}
variable admin_object_id {
  default                      = null
}

variable application_name {
  description                  = "Value of 'application' resource tag"
  default                      = "Pipeline Agents"
}

variable application_owner {
  description                  = "Value of 'owner' resource tag"
  default                      = "" # Empty string takes objectId of current user
}

variable azdo_deployment_group_name {
  default                      = null
  description                  = "Azure DevOps deployment group. Only affects self-hosted agents, not scale set agents."
}
variable azdo_environment_name {
  default                      = null
  description                  = "Azure DevOps environment. Only affects self-hosted agents, not scale set agents."
}
variable azdo_org {
  description                  = "The Azure DevOps org to join self-hosted agents to (default pool: 'Default', see linux_pipeline_agent_pool/windows_pipeline_agent_pool)"
  default                      = null
}
variable azdo_pat {
  description                  = "A Personal Access Token to access the Azure DevOps organization"
  default                      = null
}
variable azdo_project {
  description                  = "The Azure DevOps project where for deployment Group or Environment"
  default                      = ""
}
variable azdo_project_id {
  description                  = "The Azure DevOps project where the Service Connection GUID to join the scale set agents resides"
  default                      = ""
}
variable azdo_service_connection_id {
  description                  = "The Azure DevOps Service Connection GUID to join the scale set agents"
  default                      = ""
}

variable bastion_tags {
  description                  = "A map of the tags to use for the bastion resources that are deployed"
  type                         = map

  default                      = {}  
} 

variable configure_access_control {
  description                  = "Assumes the Terraform user is an owner of the subscription."
  default                      = false
  type                         = bool
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

variable demo_viewers {
  description                  = "Object ID's of AAD groups/users to be granted reader access"
  default                      = []
  type                         = list
}

variable deploy_bastion {
  description                  = "Deploys managed bastion host"
  default                      = true
  type                         = bool
}
variable deploy_files_share {
  description                  = "Deploys files share (e.g. for agent diagnostics)"
  default                      = false
  type                         = bool
}
variable deploy_firewall {
  description                  = "Deploys NAT Gateway if set to false"
  default                      = false
  type                         = bool
}
variable deploy_non_essential_vm_extensions {
  description                  = "Whether to deploy optional VM extensions"
  default                      = false
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
  description                  = "Deploys Pipeline Agent on self-hosted VMs. Variables azdo_org and azdo_pat should also be specified."
  default                      = true
  type                         = bool
}

variable destroy_wait_minutes {
  default                      = 2
  type                         = number
}

variable dns_host_suffix {
  default                      = "mycicd"
}

variable enable_firewall_dns_proxy {
  type                         = bool
  default                      = false
}
variable enable_public_access {
  type                         = bool
  default                      = false
}

variable environment_variables {
  type                         = map
  default = {
    FOO                        = "bar"
  }  
} 

variable linux_tools {
  default                      = false
  type                         = bool
}

variable linux_os_image_id {
  default                      = null
}
# az vm image list-offers -l centralus -p "Canonical" -o table
variable linux_os_offer {
  default                      = "0001-com-ubuntu-server-focal"
}
variable linux_os_publisher {
  default                      = "Canonical"
}
# az vm image list-skus -l centralus -f "0001-com-ubuntu-server-focal" -p "Canonical" -o table
variable linux_os_sku {
  default                      = "20_04-lts"
}
variable linux_os_version {
  default                      = "latest"
}
variable linux_os_vhd_url {
  default                      = null
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
variable linux_scale_set_agent_idle_count {
  default                      = 1
  type                         = number
}
variable linux_scale_set_agent_max_count {
  default                      = 8
  type                         = number
}
variable linux_scale_set_agent_max_saved_count {
  default                      = 1
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
  default                      = "centralus"
}

variable log_analytics_workspace_id {
  description                  = "Specify a pre-existing Log Analytics workspace. The workspace needs to have the Security, SecurityCenterFree, ServiceMap, Updates, VMInsights solutions provisioned"
  default                      = ""
}

variable packer_client_id {
  description                  = "When building images in a cross-tenant peered virtual network, this is needed"
  default                      = null
}
variable packer_client_secret {
  description                  = "When building images in a cross-tenant peered virtual network, this is needed"
  default                      = null
}
variable packer_address_space {
  default                      = "10.202.0.0/22"
}
variable packer_subscription_id {
  description                  = "When building images in a cross-tenant peered virtual network, this is needed"
  default                      = null
}
variable packer_tenant_id {
  description                  = "When building images in a cross-tenant peered virtual network, this is needed"
  default                      = null
}

variable pipeline_agent_diagnostics {
  description                  = "Turn on diagnostics for the pipeline agent (Agent.Diagnostic)"
  type                         = bool
  default                      = false
}

variable pipeline_agent_version_id {
  # https://api.github.com/repos/microsoft/azure-pipelines-agent/releases
  default                      = "latest"
}

variable prepare_host {
  type                         = bool
  default                      = true
}

variable resource_prefix {
  description                  = "The prefix to put at the of resource names created"
  default                      = "pipelines"
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

variable shared_image_gallery_id {
  description                  = "Bring your own Azure Compute Gallery. If not, one will be created."
  default                      = null
}
variable shutdown_time {
  default                      = "" # Empty string doesn't triggers a shutdown
  description                  = "Time the self-hosyted will be stopped daily. Setting this to null or an empty string disables auto shutdown."
}
variable ssh_private_key {
  default                      = "~/.ssh/id_rsa"
}
variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable storage_contributors {
  description                  = "Object ID's of AAD groups/users to be granted reader access e.g. Packer build identity"
  default                      = []
  type                         = list
}

variable subscription_id {
  description                  = "Configure subscription_id independent from ARM_SUBSCRIPTION_ID"
  default                      = null
}
variable tenant_id {
  description                  = "Configure tenant_id independent from ARM_TENANT_ID"
  default                      = null
}

variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map

  default = {
    shutdown                   = "false"
  }  
} 

variable timezone {
  default                      = "W. Europe Standard Time"
}

variable user_name {
  default                      = "devopsadmin"
}

variable vhd_storage_account_tier {
  default                      = "Standard"
}
variable vm_accelerated_networking {
  default                      = false
}

variable windows_os_image_id {
  default                      = null
}
# az vm image list-skus -l centralus -f "visualstudio2019latest" -p "microsoftvisualstudio" -o table
# az vm image list-skus -l centralus -f "visualstudio2022" -p "microsoftvisualstudio" -o table
# az vm image list -l centralus -f "visualstudio2022" -p "microsoftvisualstudio" -s "vs-2022-comm-latest-ws2022" -o table --all
variable windows_os_offer {
  default                      = "visualstudio2022"
}
variable windows_os_publisher {
  default                      = "microsoftvisualstudio"
}
variable windows_os_sku {
  default                      = "vs-2022-ent-latest-ws2022"
}
variable windows_os_version {
  default                      = "latest"
}
variable windows_os_vhd_url {
  default                      = null
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
variable windows_scale_set_agent_idle_count {
  default                      = 1
  type                         = number
}
variable windows_scale_set_agent_max_count {
  default                      = 8
  type                         = number
}
variable windows_scale_set_agent_max_saved_count {
  default                      = 1
  type                         = number
}
variable windows_scale_set_agent_interactive_ui {
  default                      = false
  type                         = bool
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