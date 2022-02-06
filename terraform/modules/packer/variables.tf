variable address_space {}
variable admin_cidr_ranges {
    type                       = list
    default                    = []
}
variable location {}
variable peer_virtual_network_id {}
variable suffix {}
variable tags {
    type = map
}
variable use_remote_gateway {
    type = bool
}