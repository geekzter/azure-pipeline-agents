terraform {
  required_providers {
    azuread                    = "~> 2.7"
    azurerm                    = "~> 2.86"
    cloudinit                  = "~> 2.2"
    http                       = "~> 2.1"
    local                      = "~> 2.1"
    null                       = "~> 3.1"
    random                     = "~> 3.1"
    time                       = "~> 0.7"
  }
  required_version             = "~> 1.0"
}

# Microsoft Azure Resource Manager Provider
provider azurerm {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    virtual_machine {
      # Don't do this in production
      delete_os_disk_on_deletion = true
    }
    virtual_machine_scale_set {
      roll_instances_when_required = true
    }
  }
}