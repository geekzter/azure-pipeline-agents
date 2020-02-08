variable pipeline_resource_group {
  default                      = "PipelineAgents"
}

variable pipeline_network {
  default                      = "PipelineAgents-vnet"
}

variable pipeline_subnet {
  default                      = "default"
}

variable ssh_private_key {
  default                      = "~/.ssh/id_rsa"
}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable user_name {
  default                      = "devopsadmin"
}

variable vm_name_prefix {
  default                      = "ew-ubuntu1804-agent"
}

variable vm_size {
  default                      = "Standard_D2s_v3"
}
