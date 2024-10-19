terraform {
  required_providers {
    azuread                    = "~> 2.35"
    azuredevops                = {
      source                   = "microsoft/azuredevops"
      version                  = "~> 1.0"
    }
    azurerm                    = "~> 4.6"
    cloudinit                  = "~> 2.2"
    http                       = "~> 3.4"
    local                      = "~> 2.1"
    null                       = "~> 3.1"
    random                     = "~> 3.1"
    time                       = "~> 0.7"
  }
  required_version             = "~> 1.0"
}

# Azure DevOps provider
provider azuredevops {
  org_service_url              = local.azdo_org_url
  use_oidc                     = true
}

# Microsoft Azure Resource Manager Provider
provider azurerm {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      # Don't do this in production
      delete_os_disk_on_deletion = true
    }
    virtual_machine_scale_set {
      roll_instances_when_required = true
    }
  }

  storage_use_azuread          = true
  use_oidc                     = true

# Requires admin consent:
# https://login.microsoftonline.com/${data.azurerm_subscription.default.tenant_id}/adminconsent?client_id=${var.packer_tenant_id}
  auxiliary_tenant_ids         = local.use_peer && var.packer_tenant_id != null && var.packer_tenant_id != "" ? [var.packer_tenant_id] : []

  subscription_id              = var.subscription_id != null && var.subscription_id != "" ? var.subscription_id : data.azurerm_subscription.default.subscription_id
  tenant_id                    = var.tenant_id != null && var.tenant_id != "" ? var.tenant_id : data.azurerm_subscription.default.tenant_id

}

# Multi-tenant multi-provider
# https://medium.com/microsoftazure/configure-azure-virtual-network-peerings-with-terraform-762b708a28d4
locals {
  use_peer                     = var.packer_subscription_id != null && var.packer_subscription_id != ""
}
provider azurerm {
  alias                        = "default"
  features {}
}
data azuread_client_config default {}
data azurerm_client_config default {
  provider                     = azurerm.default
}
data azurerm_subscription default {
  provider                     = azurerm.default
}
provider azurerm {
  alias                        = "peer"
  client_id                    = local.use_peer && var.packer_client_id != null && var.packer_client_id != "" ? var.packer_client_id : null
  client_secret                = local.use_peer && var.packer_client_secret != null && var.packer_client_secret != "" ? var.packer_client_secret : null
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }  
  }
  subscription_id              = local.use_peer ? var.packer_subscription_id : data.azurerm_subscription.default.subscription_id
  tenant_id                    = local.use_peer && var.packer_tenant_id != null && var.packer_tenant_id != "" ? var.packer_tenant_id : data.azurerm_subscription.default.tenant_id
# Requires admin consent:
# https://login.microsoftonline.com/${var.packer_tenant_id}/adminconsent?client_id=${data.azurerm_client_config.default.client_id}
  auxiliary_tenant_ids         = local.use_peer && var.packer_tenant_id != null && var.packer_tenant_id != "" ? [data.azurerm_subscription.default.tenant_id] : []
}