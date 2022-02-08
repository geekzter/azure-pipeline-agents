resource azurerm_policy_definition no_vm_extension {
  name                         = "no-vm-extension-policy-${terraform.workspace}-${var.suffix}"

  description                  = "VM extensions that are installed during VM image build time lead to non-deterministic outcomes, this policy aims to prevent that"
  display_name                 = "Prevent VM extensions on Packer Build VM's"
  metadata                     = jsonencode({
    "category"                 = "demo"
  })
  mode                         = "Indexed"
  policy_rule                  = file("${path.module}/no-vm-extension-policy.json")
  policy_type                  = "Custom"
}