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
  description                  = "Azure DevOps deployment group for self-hosted agents, not scale set agents."
}
variable azdo_environment_name {
  default                      = null
  description                  = "Azure DevOps environment for self-hosted agents, not scale set agents."
}
variable azure_linux_os_image_id {
  default                      = null
}
# az vm image list-offers -l centralus -p "Canonical" -o table
variable azure_linux_os_offer {
  default                      = "0001-com-ubuntu-server-focal"
}
variable azure_linux_os_publisher {
  default                      = "Canonical"
}
# az vm image list-skus -l centralus -f "0001-com-ubuntu-server-focal" -p "Canonical" -o table
variable azure_linux_os_sku {
  default                      = "20_04-lts"
}
variable azure_linux_os_version {
  default                      = "latest"
}
variable azure_linux_os_vhd_url {
  default                      = null
}
variable azdo_linux_pipeline_agent_pool {
  default                      = "Default"
}
variable azure_linux_scale_set_agent_count {
  default                      = 2
  type                         = number
}
variable azure_shared_image_gallery_id {
  description                  = "Bring your own Azure Compute Gallery. If not, one will be created."
  default                      = null
}
variable azure_windows_os_image_id {
  default                      = null
}
# az vm image list-skus -l centralus -f "visualstudio2019latest" -p "microsoftvisualstudio" -o table
# az vm image list-skus -l centralus -f "visualstudio2022" -p "microsoftvisualstudio" -o table
# az vm image list -l centralus -f "visualstudio2022" -p "microsoftvisualstudio" -s "vs-2022-comm-latest-ws2022" -o table --all
variable azure_windows_os_offer {
  default                      = "visualstudio2022"
}
variable azure_windows_os_publisher {
  default                      = "microsoftvisualstudio"
}
variable azure_windows_os_sku {
  default                      = "vs-2022-ent-latest-ws2022"
}
variable azure_windows_os_version {
  default                      = "latest"
}
variable azure_windows_os_vhd_url {
  default                      = null
}
variable azure_windows_scale_set_agent_count {
  default                      = 2
  type                         = number
}

variable azdo_linux_scale_set_agent_idle_count {
  default                      = 1
  type                         = number
}
variable azdo_linux_scale_set_agent_max_count {
  default                      = 8
  type                         = number
}
variable azdo_linux_scale_set_agent_max_saved_count {
  default                      = 1
  type                         = number
}
variable azdo_linux_scale_set_pool_name {
  description                  = "The name of the Azure DevOps Scale St pool"
  default                      = null
}
variable azdo_org {
  description                  = "The Azure DevOps org to join self-hosted agents to (default pool: 'Default', see azdo_linux_pipeline_agent_pool/azdo_windows_pipeline_agent_pool)"
  default                      = null
}
variable azdo_pat {
  description                  = "A Personal Access Token to access the Azure DevOps organization"
  default                      = null
}
variable azdo_project_names {
  description                  = "The Azure DevOps projects where Scale Set pools should be enabled"
  default                      = [] # Empty list disables scale set pools
  type                         = list
}
variable azdo_service_connection_id {
  description                  = "The Azure DevOps Service Connection GUID to join the scale set agents"
  default                      = null
}
variable azdo_windows_pipeline_agent_pool {
  default                      = "Default"
}
variable azdo_windows_scale_set_agent_idle_count {
  default                      = 1
  type                         = number
}
variable azdo_windows_scale_set_agent_max_count {
  default                      = 8
  type                         = number
}
variable azdo_windows_scale_set_agent_max_saved_count {
  default                      = 1
  type                         = number
}
variable azdo_windows_scale_set_agent_interactive_ui {
  default                      = false
  type                         = bool
}
variable azdo_windows_scale_set_pool_name {
  description                  = "The name of the Azure DevOps Scale St pool"
  default                      = null
}

variable azure_address_space {
  default                      = "10.201.0.0/22"
}
variable azure_admin_ip_ranges {
  default                      = []
  type                         = list
}
variable azure_admin_object_id {
  default                      = null
}
variable azure_bastion_tags {
  description                  = "A map of the tags to use for the bastion resources that are deployed"
  type                         = map

  default                      = {}  
} 
variable azure_location {
  default                      = "centralus"
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

variable create_packer_infrastructure {
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

variable azure_linux_pipeline_agent_name_prefix {
  default                      = "ubuntu-agent"
}

variable azure_linux_self_hosted_agent_count {
  default                      = 1
  type                         = number
}
variable azure_linux_storage_type {
  default                      = "Standard_LRS"
}
variable azure_linux_vm_size {
  default                      = "Standard_D2s_v3"
}
variable azure_log_analytics_workspace_id {
  description                  = "Specify a pre-existing Log Analytics workspace. The workspace needs to have the Security, SecurityCenterFree, ServiceMap, Updates, VMInsights solutions provisioned"
  default                      = ""
}
variable azure_vhd_storage_account_tier {
  default                      = "Standard"
}
variable azure_vm_accelerated_networking {
  default                      = false
}
variable azure_windows_self_hosted_agent_count {
  default                      = 1
  type                         = number
}
variable azure_windows_storage_type {
  default                      = "Standard_LRS"
}
variable azure_windows_vm_size {
  default                      = "Standard_D4s_v3"
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


variable windows_pipeline_agent_name_prefix {
  default                      = "windows-agent"
}