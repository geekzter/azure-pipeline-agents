locals {
  policy_metadata              = {
    application                = "Pipeline Agents"
    provisioner                = "terraform"
    workspace                  = terraform.workspace
  }
}

resource azurerm_policy_definition no_vm_extension {
  name                         = "pipeline-build-no-vm-extension-policy-${terraform.workspace}-${var.suffix}"

  description                  = "VM extensions that are installed during VM image build time lead to non-deterministic outcomes, this policy aims to prevent that"
  display_name                 = "Prevent VM extensions on Packer Build VM's"
  metadata                     = jsonencode(local.policy_metadata)
  mode                         = "Indexed"
  policy_rule                  = file("${path.module}/no-vm-extension-policy.json")
  policy_type                  = "Custom"

  count                        = var.configure_policy ? 1 : 0
}

resource azurerm_policy_set_definition build_policies {
  name                         = "pipeline-build-policies-${terraform.workspace}-${var.suffix}"
  policy_type                  = "Custom"
  display_name                 = "Policies required for Packer image builds to succeeed"
  metadata                     = jsonencode(local.policy_metadata)

  policy_definition_reference {
    policy_definition_id       = azurerm_policy_definition.no_vm_extension.0.id
  }

  count                        = var.configure_policy ? 1 : 0
}

resource azurerm_resource_group_policy_assignment vm_policies {
  name                         = azurerm_policy_set_definition.build_policies.0.name
  location                     = azurerm_resource_group.build.location
  resource_group_id            = azurerm_resource_group.build.id
  policy_definition_id         = azurerm_policy_set_definition.build_policies.0.id

  identity {
    type                       = "SystemAssigned"
  }

  count                        = var.configure_policy ? 1 : 0
}