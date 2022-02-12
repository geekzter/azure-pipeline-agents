resource azurerm_policy_definition no_vm_extension {
  name                         = "pipeline-build-no-vm-extension-policy-${terraform.workspace}-${var.suffix}"

  description                  = "VM extensions that are installed during VM image build time lead to non-deterministic outcomes, this policy aims to prevent that"
  display_name                 = "Prevent VM extensions on Packer Build VM's"
  metadata                     = jsonencode({
    "category"                 = "demo"
  })
  mode                         = "Indexed"
  policy_rule                  = file("${path.module}/no-vm-extension-policy.json")
  policy_type                  = "Custom"
}

resource azurerm_policy_set_definition build_policies {
  name                         = "pipeline-build-policies-${terraform.workspace}-${var.suffix}"
  policy_type                  = "Custom"
  display_name                 = "Policies required for Packer image builds to succeeed"

  policy_definition_reference {
    policy_definition_id       = azurerm_policy_definition.no_vm_extension.id
  }
}

resource azurerm_resource_group_policy_assignment vm_policies {
  name                         = azurerm_policy_set_definition.build_policies.name
  location                     = azurerm_resource_group.build.location
  resource_group_id            = azurerm_resource_group.build.id
  policy_definition_id         = azurerm_policy_set_definition.build_policies.id

  identity {
    type                       = "SystemAssigned"
  }
}