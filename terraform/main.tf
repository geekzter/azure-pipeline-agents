data http terraform_ip_address {
# Get public IP address of the machine running this terraform template
  url                          = "https://ipinfo.io/ip"
}

data http terraform_ip_prefix {
# Get public IP prefix of the machine running this terraform template
  url                          = "https://stat.ripe.net/data/network-info/data.json?resource=${chomp(data.http.terraform_ip_address.body)}"
}

# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  number                       = false
  special                      = false
}

# Random password generator
resource random_string password {
  length                       = 12
  upper                        = true
  lower                        = true
  number                       = true
  special                      = true
# override_special             = "!@#$%&*()-_=+[]{}<>:?" # default
# Avoid characters that may cause shell scripts to break
  override_special             = "." 
}

locals {
  configuration_bitmask        = (
                                  (var.configure_cidr_allow_rules         ? pow(2,0) : 0) +
                                  (var.configure_wildcard_allow_rules     ? pow(2,1) : 0) +
                                  (var.deploy_bastion                     ? pow(2,2) : 0) +
                                  (var.deploy_firewall                    ? pow(2,3) : 0) +
                                  (var.deploy_non_essential_vm_extensions ? pow(2,4) : 0) +
                                  (var.deploy_scale_set                   ? pow(2,5) : 0) +
                                  (var.deploy_self_hosted_vms             ? pow(2,6) : 0) +
                                  (var.deploy_self_hosted_vm_agents       ? pow(2,7) : 0) +
                                  (var.prepare_host                       ? pow(2,8) : 0) +
                                  (var.configure_crl_oscp_rules           ? pow(2,9) : 0) +
                                  0
  )

  environment                  = "dev"
  environment_variables        = merge(
    {
      "Agent.Diagnostic"                                        = var.pipeline_agent_diagnostics
      PIPELINE_DEMO_AGENT_OUTBOUND_IP                           = module.network.outbound_ip_address
      PIPELINE_DEMO_AGENT_SUBNET_ID                             = module.network.scale_set_agents_subnet_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_CLIENT_ID      = azurerm_user_assigned_identity.agents.client_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_NAME           = azurerm_user_assigned_identity.agents.name
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_PRINCIPAL_ID   = azurerm_user_assigned_identity.agents.principal_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_RESOURCE_ID    = azurerm_user_assigned_identity.agents.id
      PIPELINE_DEMO_AGENT_VIRTUAL_NETWORK_ID                    = module.network.virtual_network_id
      PIPELINE_DEMO_AGENT_LOCATION                              = var.location
      PIPELINE_DEMO_COMPUTE_GALLERY_ID                          = module.gallery.shared_image_gallery_id
      PIPELINE_DEMO_COMPUTE_GALLERY_NAME                        = split("/",module.gallery.shared_image_gallery_id)[8]
      PIPELINE_DEMO_COMPUTE_GALLERY_RESOURCE_GROUP_ID           = join("/",slice(split("/",module.gallery.shared_image_gallery_id),0,5))
      PIPELINE_DEMO_COMPUTE_GALLERY_RESOURCE_GROUP_NAME         = split("/",module.gallery.shared_image_gallery_id)[4]
      PIPELINE_DEMO_PACKER_BUILD_RESOURCE_GROUP_ID              = join("/",slice(split("/",module.packer.build_resource_group_id),0,5))
      PIPELINE_DEMO_PACKER_BUILD_RESOURCE_GROUP_NAME            = split("/",module.packer.build_resource_group_id)[4]
      PIPELINE_DEMO_PACKER_LOCATION                             = var.location
      PIPELINE_DEMO_PACKER_POLICY_SET_NAME                      = module.packer.policy_set_name
      PIPELINE_DEMO_PACKER_STORAGE_ACCOUNT_ID                   = module.packer.storage_account_id
      PIPELINE_DEMO_PACKER_STORAGE_ACCOUNT_NAME                 = module.packer.storage_account_name
      PIPELINE_DEMO_PACKER_STORAGE_ACCOUNT_RESOURCE_GROUP_ID    = join("/",slice(split("/",module.packer.storage_account_id),0,5))
      PIPELINE_DEMO_PACKER_STORAGE_ACCOUNT_RESOURCE_GROUP_NAME  = split("/",module.packer.storage_account_id)[4]
      PIPELINE_DEMO_PACKER_SUBNET_NAME                          = module.packer.packer_subnet_name
      PIPELINE_DEMO_PACKER_VIRTUAL_NETWORK_ID                   = module.packer.virtual_network_id
      PIPELINE_DEMO_PACKER_VIRTUAL_NETWORK_NAME                 = split("/",module.packer.virtual_network_id)[8]
      PIPELINE_DEMO_PACKER_VIRTUAL_NETWORK_RESOURCE_GROUP_ID    = join("/",slice(split("/",module.packer.virtual_network_id),0,5))
      PIPELINE_DEMO_PACKER_VIRTUAL_NETWORK_RESOURCE_GROUP_NAME  = split("/",module.packer.virtual_network_id)[4]
      PIPELINE_DEMO_VHD_STORAGE_ACCOUNT_ID                      = module.gallery.storage_account_id
      PIPELINE_DEMO_VHD_STORAGE_ACCOUNT_NAME                    = module.gallery.storage_account_name
      PIPELINE_DEMO_VHD_STORAGE_ACCOUNT_RESOURCE_GROUP_ID       = join("/",slice(split("/",module.gallery.storage_account_id),0,5))
      PIPELINE_DEMO_VHD_STORAGE_ACCOUNT_RESOURCE_GROUP_NAME     = split("/",module.gallery.storage_account_id)[4]
      PIPELINE_DEMO_VHD_STORAGE_CONTAINER_ID                    = module.gallery.storage_container_id
      PIPELINE_DEMO_VHD_STORAGE_CONTAINER_NAME                  = module.gallery.storage_container_name
      "System.Debug"                                            = var.pipeline_agent_diagnostics
      SYSTEM_DEBUG                                              = var.pipeline_agent_diagnostics
      VSTS_AGENT_HTTPTRACE                                      = var.pipeline_agent_diagnostics
    },
    var.environment_variables
  )
  password                     = ".Az9${random_string.password.result}"
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  tags                         = merge(
    {
      application              = "Pipeline Agents"
      environment              = local.environment
      provisioner              = "terraform"
      provisioner-client-id    = data.azurerm_client_config.default.client_id
      provisioner-object-id    = data.azuread_client_config.default.object_id
      repository               = "azure-pipeline-agents"
      runid                    = var.run_id
      shutdown                 = "false"
      suffix                   = local.suffix
      workspace                = terraform.workspace
      configuration-bitmask    = local.configuration_bitmask
    },
    var.tags
  )  
  terraform_ip_address         = chomp(data.http.terraform_ip_address.body)
  terraform_ip_prefix          = jsondecode(chomp(data.http.terraform_ip_prefix.body)).data.prefix

  # Networking
  admin_cidr_ranges            = sort(distinct(concat([for range in var.admin_ip_ranges : cidrsubnet(range,0,0)],tolist([local.terraform_ip_address])))) # Make sure ranges have correct base address
}

resource null_resource script_wrapper_check {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    command                    = "echo Terraform should be called from deploy.ps1, hit Ctrl-C to exit"
  }

  count                        = var.script_wrapper_check ? 1 : 0
}
resource time_sleep script_wrapper_check {
  triggers                     = {
    always_run                 = timestamp()
  }

  create_duration              = "999999h"

  count                        = var.script_wrapper_check ? 1 : 0
  depends_on                   = [null_resource.script_wrapper_check]
}

resource azurerm_resource_group rg {
  name                         = terraform.workspace == "default" ? "pipeline-agents-${local.suffix}" : "pipeline-${terraform.workspace}-agents-${local.suffix}"
  location                     = var.location
  tags                         = local.tags

  depends_on                   = [time_sleep.script_wrapper_check]
}