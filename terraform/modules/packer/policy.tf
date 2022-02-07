resource azurerm_policy_definition no_vm_extension {
  name                         = "no-vm-extension-policy-${var.suffix}"
  policy_type                  = "Custom"
  mode                         = "Indexed"
  description                  = "VM extensions that are installed during VM image build time lead to non-deterministic outcomes, this policy aims to prevent that"
  display_name                 = "Prevent VM extensions on Packer Build VM's"

  policy_rule                  = file("${path.module}/no-vm-extension-policy.json")
}