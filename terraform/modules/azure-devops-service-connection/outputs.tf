output service_connection_id {
  value       = azuredevops_serviceendpoint_azurerm.azurerm.id
}
output service_connection_name {
  value       = azuredevops_serviceendpoint_azurerm.azurerm.service_endpoint_name 
}
output service_connection_oidc_issuer {
  value       = azuredevops_serviceendpoint_azurerm.azurerm.workload_identity_federation_issuer
}
output service_connection_oidc_subject {
  value       = azuredevops_serviceendpoint_azurerm.azurerm.workload_identity_federation_subject
}
output service_connection_url {
  value       = "${data.azuredevops_client_config.current.organization_url}/${var.project_id}/_settings/adminservices?resourceId=${azuredevops_serviceendpoint_azurerm.azurerm.id}"
}