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

  config_directory             = "${formatdate("YYYY",timestamp())}/${formatdate("MM",timestamp())}/${formatdate("DD",timestamp())}/${formatdate("hhmm",timestamp())}"
  environment                  = "dev"
  environment_variables        = {
    "GEEKZTER_AGENT_SUBNET_ID"= module.network.scale_set_agents_subnet_id
    "GEEKZTER_AGENT_OUTBOUND_IP"= module.network.outbound_ip_address
    "GEEKZTER_AGENT_VIRTUAL_NETWORK_ID"=module.network.virtual_network_id
    "GEEKZTER_PACKER_STORAGE_ACCOUNT_NAME"=module.packer.storage_account_name
    "GEEKZTER_PACKER_SUBNET_NAME"="Packer"
    "GEEKZTER_PACKER_VIRTUAL_NETWORK_NAME"=split("/",module.network.virtual_network_id)[8]
    "GEEKZTER_PACKER_VIRTUAL_NETWORK_RESOURCE_GROUP_NAME"=azurerm_resource_group.rg.name
  }
  password                     = ".Az9${random_string.password.result}"
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  tags                         = merge(
    {
      application              = "Pipeline Agents"
      environment              = local.environment
      provisioner              = "terraform"
      provisioner-client-id    = data.azurerm_client_config.current.client_id
      provisioner-object-id    = data.azurerm_client_config.current.object_id
      repository               = "azure-pipeline-agents"
      runid                    = var.run_id
      shutdown                 = "false"
      suffix                   = local.suffix
      workspace                = terraform.workspace
      configuration-bitmask    = local.configuration_bitmask
    },
    var.tags
  )  

  # Networking
  ipprefix                     = jsondecode(chomp(data.http.local_public_prefix.body)).data.prefix
  admin_cidr_ranges            = sort(distinct(concat([for range in var.admin_ip_ranges : cidrsubnet(range,0,0)],tolist([local.ipprefix])))) # Make sure ranges have correct base address
}

data azurerm_client_config current {}

data http local_public_ip {
# Get public IP address of the machine running this terraform template
  url                          = "https://ipinfo.io/ip"
}

data http local_public_prefix {
# Get public IP prefix of the machine running this terraform template
  url                          = "https://stat.ripe.net/data/network-info/data.json?resource=${chomp(data.http.local_public_ip.body)}"
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
  name                         = terraform.workspace == "default" ? "azure-pipelines-agents-${local.suffix}" : "azure-pipelines-agents-${terraform.workspace}-${local.suffix}"
  location                     = var.location
  tags                         = local.tags

  depends_on                   = [time_sleep.script_wrapper_check]
}

resource azurerm_role_assignment service_principal_contributor {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Contributor"
  principal_id                 = module.service_principal.0.principal_id

  count                        = var.create_contributor_service_principal ? 1 : 0
}

resource azurerm_role_assignment demo_viewer {
  scope                        = azurerm_resource_group.rg.id
  role_definition_name         = "Reader"
  principal_id                 = each.key

  for_each                     = toset(var.demo_viewers)
}
