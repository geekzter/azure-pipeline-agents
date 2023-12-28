variable address_space {}
variable admin_cidr_ranges {
    type                       = list
}
variable agent_address_range {}
variable configure_policy {
    type                       = bool
}
variable deploy_nat_gateway {
    type                       = bool
}
variable gateway_ip_address {
    default                    = null
}
variable location {}
variable peer_virtual_network_id {}
variable prefix {}
variable suffix {}
variable tags {
    type                       = map
}