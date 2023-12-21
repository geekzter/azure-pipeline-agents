variable create_federation {
  type   = bool
}
variable issuer {}
variable federation_subject {}
# If true, the Service Principal will be created as multi-tenant
# Add the Service Principal to the tenant using the following URL:
# https://login.microsoftonline.com/<tenantId>/adminconsent?client_id=<appId>
variable multi_tenant {
  type   = bool
}
variable name {}
variable owner_object_id {
  default = null
}