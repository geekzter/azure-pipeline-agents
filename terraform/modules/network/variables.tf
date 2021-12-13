variable address_space {}
variable configuration_name {
    description = "This value is appended to Azure FW rule names, so it can be parsed in Log Analytics queries"
}
variable configure_cidr_allow_rules {
    type = bool
}
variable configure_crl_oscp_rules {
    type = bool
}
variable configure_wildcard_allow_rules {
    type = bool
}
variable deploy_bastion {
    type = bool
}
variable deploy_firewall {
    type = bool
}
variable destroy_wait_minutes {
    type = number
}
variable devops_org {}
variable diagnostics_storage_id {}
variable dns_host_suffix {}
variable location {}
variable log_analytics_workspace_resource_id {}
variable resource_group_name {}
variable tags {
    type = map
}
