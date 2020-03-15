# Microsoft Azure Resource Manager Provider

#
# This provider block uses the following environment variables: 
# ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET and ARM_TENANT_ID
#
provider "azurerm" {
    version = "~> 2.0"
    features {
        virtual_machine {
            delete_os_disk_on_deletion = true
        }
    } 
}