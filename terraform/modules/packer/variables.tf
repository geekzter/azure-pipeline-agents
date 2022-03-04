variable address_space {}
variable admin_cidr_ranges {
    type                       = list
}
variable agent_address_range {}
variable deploy_nat_gateway {
    type                       = bool
}
variable gateway_ip_address {
    default                    = null
}
variable location {}
variable peer_virtual_network_id {}
variable suffix {}
variable tags {
    type                       = map
}