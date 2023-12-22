data azuread_client_config current {}

locals {
  owner_object_id              = var.owner_object_id != null && var.owner_object_id != "" ? lower(var.owner_object_id) : data.azuread_client_config.current.object_id
}

resource azuread_application app_registration {
  display_name                 = var.name
  owners                       = [local.owner_object_id]
  sign_in_audience             = var.multi_tenant ? "AzureADMultipleOrgs" : null
}

resource azuread_service_principal spn {
  client_id                    = azuread_application.app_registration.client_id
  owners                       = [local.owner_object_id]
}

resource azuread_application_federated_identity_credential fic {
  application_object_id        = azuread_application.app_registration.object_id
  description                  = "Created by Terraform"
  display_name                 = replace(var.federation_subject,"/[:/ ]+/","-")
  audiences                    = ["api://AzureADTokenExchange"]
  issuer                       = var.issuer
  subject                      = var.federation_subject

  count                        = var.create_federation ? 1 : 0
}

resource time_rotating secret_expiration {
  rotation_years               = 1

  count                        = var.create_federation ? 0 : 1
}
resource azuread_application_password secret {
  rotate_when_changed          = {
    rotation                   = timeadd(time_rotating.secret_expiration.0.id, "8760h") # One year from now
  }

  application_object_id        = azuread_application.app_registration.id

  count                        = var.create_federation ? 0 : 1
}