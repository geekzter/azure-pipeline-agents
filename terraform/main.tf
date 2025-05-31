data http terraform_ip_address {
# Get public IP address of the machine running this terraform template
  url                          = "https://ipinfo.io/ip"
  retry {
    attempts                   = 4
  }
}

data http terraform_ip_prefix {
# Get public IP prefix of the machine running this terraform template
  url                          = "https://stat.ripe.net/data/network-info/data.json?resource=${chomp(data.http.terraform_ip_address.response_body)}"
  retry {
    attempts                   = 4
  }
}

# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  numeric                      = false
  special                      = false
}

# Random password generator
resource random_string password {
  length                       = 12
  upper                        = true
  lower                        = true
  numeric                      = true
  special                      = true
# override_special             = "!@#$%&*()-_=+[]{}<>:?" # default
# Avoid characters that may cause shell scripts to break
  override_special             = "." 
}

locals {
  configuration_bitmask        = (
                                  (var.configure_azure_cidr_allow_rules         ? pow(2,0) : 0) +
                                  (var.configure_azure_wildcard_allow_rules     ? pow(2,1) : 0) +
                                  (var.deploy_azure_bastion                     ? pow(2,2) : 0) +
                                  (var.deploy_azure_firewall                    ? pow(2,3) : 0) +
                                  (var.deploy_non_essential_azure_vm_extensions ? pow(2,4) : 0) +
                                  (var.deploy_azure_scale_set                   ? pow(2,5) : 0) +
                                  (var.deploy_azure_self_hosted_vms             ? pow(2,6) : 0) +
                                  (var.deploy_azdo_self_hosted_vm_agents        ? pow(2,7) : 0) +
                                  (var.prepare_host                             ? pow(2,8) : 0) +
                                  (var.configure_azure_crl_oscp_rules           ? pow(2,9) : 0) +
                                  0
  )
  environment                  = "dev"
  environment_variables        = merge(
    {
      # "Agent.Diagnostic"                                        = tostring(var.azdo_pipeline_agent_diagnostics)
      AGENT_DIAGNOSTIC                                          = tostring(var.azdo_pipeline_agent_diagnostics)
      PIPELINE_DEMO_AGENT_LOCATION                              = var.azure_location
      PIPELINE_DEMO_AGENT_OUTBOUND_IP                           = module.network.outbound_ip_address
      PIPELINE_DEMO_AGENT_SUBNET_ID                             = module.network.scale_set_agents_subnet_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_CLIENT_ID      = azurerm_user_assigned_identity.agents.client_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_NAME           = azurerm_user_assigned_identity.agents.name
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_PRINCIPAL_ID   = azurerm_user_assigned_identity.agents.principal_id
      PIPELINE_DEMO_AGENT_USER_ASSIGNED_IDENTITY_RESOURCE_ID    = azurerm_user_assigned_identity.agents.id
      PIPELINE_DEMO_AGENT_VIRTUAL_NETWORK_ID                    = module.network.virtual_network_id
      PIPELINE_DEMO_APPLICATION_NAME                            = var.application_name
      PIPELINE_DEMO_APPLICATION_OWNER                           = local.owner
      PIPELINE_DEMO_COMPUTE_GALLERY_ID                          = var.create_azure_packer_infrastructure ? module.gallery.0.shared_image_gallery_id : ""
      PIPELINE_DEMO_COMPUTE_GALLERY_NAME                        = var.create_azure_packer_infrastructure ? split("/",module.gallery.0.shared_image_gallery_id)[8] : ""
      PIPELINE_DEMO_COMPUTE_GALLERY_RESOURCE_GROUP_ID           = var.create_azure_packer_infrastructure ? join("/",slice(split("/",module.gallery.0.shared_image_gallery_id),0,5)) : ""
      PIPELINE_DEMO_COMPUTE_GALLERY_RESOURCE_GROUP_NAME         = var.create_azure_packer_infrastructure ? split("/",module.gallery.0.shared_image_gallery_id)[4] : ""
      PIPELINE_DEMO_PACKER_BUILD_RESOURCE_GROUP_ID              = var.create_azure_packer_infrastructure ? join("/",slice(split("/",module.packer.0.build_resource_group_id),0,5)) : ""
      PIPELINE_DEMO_PACKER_BUILD_RESOURCE_GROUP_NAME            = var.create_azure_packer_infrastructure ? split("/",module.packer.0.build_resource_group_id)[4] : ""
      PIPELINE_DEMO_PACKER_LOCATION                             = var.create_azure_packer_infrastructure ? var.azure_location : ""
      PIPELINE_DEMO_PACKER_POLICY_SET_NAME                      = var.create_azure_packer_infrastructure && var.configure_access_control ? module.packer.0.policy_set_name : ""
      PIPELINE_DEMO_PACKER_SUBNET_NAME                          = var.create_azure_packer_infrastructure ? module.packer.0.packer_subnet_name : ""
      PIPELINE_DEMO_PACKER_VIRTUAL_NETWORK_ID                   = var.create_azure_packer_infrastructure ? module.packer.0.virtual_network_id : ""
      PIPELINE_DEMO_PACKER_VIRTUAL_NETWORK_NAME                 = var.create_azure_packer_infrastructure ? split("/",module.packer.0.virtual_network_id)[8] : ""
      PIPELINE_DEMO_PACKER_VIRTUAL_NETWORK_RESOURCE_GROUP_ID    = var.create_azure_packer_infrastructure ? join("/",slice(split("/",module.packer.0.virtual_network_id),0,5)) : ""
      PIPELINE_DEMO_PACKER_VIRTUAL_NETWORK_RESOURCE_GROUP_NAME  = var.create_azure_packer_infrastructure ? split("/",module.packer.0.virtual_network_id)[4] : ""
      PIPELINE_DEMO_RESOURCE_PREFIX                             = var.resource_prefix
      # "System.Debug"                                            = tostring(var.pipeline_agent_diagnostics)
      SYSTEM_DEBUG                                              = tostring(var.azdo_pipeline_agent_diagnostics)

      # https://github.com/actions/runner-images/blob/main/docs/create-image-and-azure-resources.md#network-security
      VNET_RESOURCE_GROUP                                       = var.create_azure_packer_infrastructure ? split("/",module.packer.0.virtual_network_id)[4] : ""
      VNET_NAME                                                 = var.create_azure_packer_infrastructure ? split("/",module.packer.0.virtual_network_id)[8] : ""
      VNET_SUBNET                                               = var.create_azure_packer_infrastructure ? module.packer.0.packer_subnet_name : ""

      VSTSAGENT_TRACE                                           = tostring(var.azdo_pipeline_agent_diagnostics)
      VSTS_AGENT_HTTPTRACE                                      = tostring(var.azdo_pipeline_agent_diagnostics)
    },
    var.environment_variables
  )
  owner                        = var.application_owner != "" ? var.application_owner : data.azuread_client_config.default.object_id
  password                     = ".Az9${random_string.password.result}"
  suffix                       = var.resource_suffix != "" ? lower(var.resource_suffix) : random_string.suffix.result
  tags                         = merge(
    {
      application              = var.application_name
      environment              = local.environment
      github-repo              = "https://github.com/geekzter/azure-pipeline-agents"
      owner                    = local.owner
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
    var.azure_tags
  )  
  terraform_ip_address         = chomp(data.http.terraform_ip_address.response_body)
  terraform_ip_prefix          = jsondecode(chomp(data.http.terraform_ip_prefix.response_body)).data.prefix

  # Networking
  admin_cidr_ranges            = sort(distinct(concat([for range in var.azure_admin_ip_ranges : cidrsubnet(range,0,0)],tolist([local.terraform_ip_address])))) # Make sure ranges have correct base address
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
  name                         = terraform.workspace == "default" ? "${var.resource_prefix}-${var.resource_middle_name}-${local.suffix}" : "${var.resource_prefix}-${terraform.workspace}-${var.resource_middle_name}-${local.suffix}"
  location                     = var.azure_location
  tags                         = local.tags

  depends_on                   = [time_sleep.script_wrapper_check]
}

resource azurerm_key_vault vault {
  name                         = substr(lower(replace("${azurerm_resource_group.rg.name}-vlt","/-|a|e|i|o|u|y/","")),0,24)
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  tenant_id                    = data.azuread_client_config.default.tenant_id

  enabled_for_disk_encryption  = true
  purge_protection_enabled     = false
  sku_name                     = "premium"

  # Grant access to self
  access_policy {
    tenant_id                  = data.azuread_client_config.default.tenant_id
    object_id                  = data.azuread_client_config.default.object_id

    key_permissions            = [
                                "Create",
                                "Delete",
                                "Get",
                                "List",
                                "Purge",
                                "Recover",
                                "UnwrapKey",
                                "WrapKey",
    ]
    secret_permissions         = [
                                "Delete",
                                "Get",
                                "List",
                                "Purge",
                                "Set",
    ]
  }

  # Grant access to admin, if defined
  dynamic "access_policy" {
    for_each = range(var.azure_admin_object_id != null && var.azure_admin_object_id != "" ? 1 : 0) 
    content {
      tenant_id                = data.azurerm_client_config.default.tenant_id
      object_id                = var.azure_admin_object_id

      key_permissions          = [
                                "Create",
                                "Get",
                                "List",
                                "Purge",
      ]

      secret_permissions       = [
                                "List",
                                "Purge",
                                "Set",
      ]
    }
  }

  dynamic "network_acls" {
    for_each = range(var.deploy_azure_firewall ? 1 : 0) 
    content {
      default_action           = "Deny"
      bypass                   = "AzureServices"
      ip_rules                 = local.admin_cidr_ranges
    }
  }

  tags                         = azurerm_resource_group.rg.tags
}
resource azurerm_private_endpoint vault_endpoint {
  name                         = "${azurerm_key_vault.vault.name}-endpoint"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  
  subnet_id                    = module.network.private_endpoint_subnet_id

  private_service_connection {
    is_manual_connection       = false
    name                       = "${azurerm_key_vault.vault.name}-endpoint-connection"
    private_connection_resource_id = azurerm_key_vault.vault.id
    subresource_names          = ["vault"]
  }

  provisioner local-exec {
    command                    = "az resource wait --updated --ids ${self.subnet_id}"
  }

  tags                         = local.tags

  depends_on                   = [
                                  module.network
  ]
  count                        = var.deploy_azure_firewall ? 1 : 0
}
resource azurerm_private_dns_a_record vault_dns_record {
  name                         = azurerm_key_vault.vault.name
  zone_name                    = module.network.azurerm_private_dns_zone_vault_name
  resource_group_name          = azurerm_resource_group.rg.name
  ttl                          = 300
  records                      = [azurerm_private_endpoint.vault_endpoint.0.private_service_connection[0].private_ip_address]

  tags                         = local.tags

  count                        = var.deploy_azure_firewall ? 1 : 0
}
resource azurerm_monitor_diagnostic_setting key_vault {
  name                         = "${azurerm_key_vault.vault.name}-logs"
  target_resource_id           = azurerm_key_vault.vault.id
  log_analytics_workspace_id   = local.log_analytics_workspace_id

  enabled_log {
    category                   = "AuditEvent"
  }

  enabled_metric {
    category                   = "AllMetrics"
  }
}

# Useful when using Bastion
resource azurerm_key_vault_secret ssh_private_key {
  name                         = "ssh-private-key"
  value                        = file(var.ssh_private_key)
  key_vault_id                 = azurerm_key_vault.vault.id
}

resource azurerm_key_vault_secret user_name {
  name                         = "user-name"
  value                        = var.user_name
  key_vault_id                 = azurerm_key_vault.vault.id
}
resource azurerm_key_vault_secret user_password {
  name                         = "user-password"
  value                        = local.password
  key_vault_id                 = azurerm_key_vault.vault.id
}

resource azurerm_ssh_public_key ssh_key {
  name                         = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  public_key                   = file(var.ssh_public_key)

  tags                         = azurerm_resource_group.rg.tags
}