variable devops_org {}
variable devops_pat {}

variable pipeline_agent_name {
  # Defaults to VM name if empty string
  default                      = ""
}

variable pipeline_agent_pool {
  default                      = "Ubuntu"
}

variable pipeline_resource_group {
  default                      = "PipelineAgents"
}

variable pipeline_network {
  default                      = "PipelineAgents-vnet"
}

variable pipeline_subnet {
  default                      = "default"
}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable user_name {
  default                      = "devopsadmin"
}

variable vm_name_prefix {
  default                      = "ubuntu1804-agent"
}

variable vm_size {
  default                      = "Standard_D2s_v3"
}
