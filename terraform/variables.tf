
variable devops_org {}
variable devops_pat {}

variable linux_agent_count {
  default                      = 1
}
variable linux_os_offer {
  default                      = "UbuntuServer"
}
variable linux_os_publisher {
  default                      = "Canonical"
}
variable linux_os_sku {
  default                      = "18.04-LTS"
}
variable linux_pipeline_agent_name {
  # Defaults to VM name if empty string
  default                      = "ubuntu1804-agent"
}
variable linux_pipeline_agent_pool {
  default                      = "Ubuntu"
}
variable linux_vm_name_prefix {
  default                      = "ubuntu1804-agent"
}
variable linux_vm_size {
  default                      = "Standard_D2s_v3"
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

variable provision_linux {
  type                         = bool
  default                      = false
}
variable provision_windows {
  type                         = bool
  default                      = true
}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable user_name {
  default                      = "devopsadmin"
}

variable vm_accelerated_networking {
  default                      = false
}

variable windows_agent_count {
  default                      = 1
}
variable windows_os_offer {
  default                      = "WindowsServer"
}
variable windows_os_publisher {
  default                      = "MicrosoftWindowsServer"
}
variable windows_os_sku {
  default                      = "2019-Datacenter"
}
variable windows_pipeline_agent_name {
  # Defaults to VM name if empty string
  default                      = "windows-agent"
}
variable windows_pipeline_agent_pool {
  default                      = "Windows"
}
variable windows_vm_name_prefix {
  default                      = "win"
}
variable windows_vm_size {
  default                      = "Standard_D4s_v3"
}