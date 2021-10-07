locals {
  locations                    = [ 
    # Get regions: az account list-locations --query "[].name"
    "asia",
    "asiapacific",
    "australia",
    "australiacentral",
    "australiacentral2",
    "australiaeast",
    "australiasoutheast",
    "brazil",
    "brazilsouth",
    "brazilsoutheast",
    "canada",
    "canadacentral",
    "canadaeast",
    "centralindia",
    "centralus",
    "centraluseuap",
    "centralusstage",
    "eastasia",
    "eastasiastage",
    "eastus",
    "eastus2",
    "eastus2euap",
    "eastus2stage",
    "eastusslv",
    "eastusstage",
    "europe",
    "france",
    "francecentral",
    "francesouth",
    "germany",
    "germanynorth",
    "germanywestcentral",
    "global",
    "india",
    "japan",
    "japaneast",
    "japanwest",
    "jioindiacentral",
    "jioindiawest",
    "korea",
    "koreacentral",
    "koreasouth",
    "northcentralus",
    "northcentralusstage",
    "northeurope",
    "norway",
    "norwayeast",
    "norwaywest",
    "qatarcentral",
    "southafrica",
    "southafricanorth",
    "southafricawest",
    "southcentralus",
    "southcentralusstage",
    "southeastasia",
    "southeastasiastage",
    "southindia",
    "swedencentral",
    "switzerland",
    "switzerlandnorth",
    "switzerlandwest",
    "uae",
    "uaecentral",
    "uaenorth",
    "uk",
    "uksouth",
    "ukwest",
    "unitedstates",
    "westcentralus",
    "westeurope",
    "westindia",
    "westus",
    "westus2",
    "westus2stage",
    "westus3",
    "westusstage",
  ]
}

resource azurerm_subnet fw_subnet {
  name                         = "AzureFirewallSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.pipeline_network.address_space[0],2,0)]

  count                        = var.use_firewall ? 1 : 0
}

resource azurerm_ip_group agents {
  name                         = "agents-ip-group"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = concat(azurerm_subnet.scale_set_agents.address_prefixes,azurerm_subnet.self_hosted_agents.address_prefixes)

  tags                         = var.tags

  count                        = var.use_firewall ? 1 : 0
}

resource azurerm_ip_group vnet {
  name                         = "${azurerm_virtual_network.pipeline_network.name}-ip-group"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = azurerm_virtual_network.pipeline_network.address_space

  tags                         = var.tags

  count                        = var.use_firewall ? 1 : 0
}

resource azurerm_public_ip firewall {
  name                         = "${var.resource_group_name}-fw-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard" # Zone redundant

  tags                         = var.tags

  count                        = var.use_firewall ? 1 : 0
}

resource azurerm_firewall firewall {
  name                         = "${var.resource_group_name}-fw"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  # Make zone redundant
  zones                        = [1,2]

  ip_configuration {
    name                       = "fw_ipconfig"
    subnet_id                  = azurerm_subnet.fw_subnet.0.id
    public_ip_address_id       = azurerm_public_ip.firewall.0.id
  }

  tags                         = var.tags

  count                        = var.use_firewall ? 1 : 0
}

# Outbound domain whitelisting
resource azurerm_firewall_application_rule_collection fw_app_rules {
  name                         = "${azurerm_firewall.firewall.0.name}-app-rules"
  azure_firewall_name          = azurerm_firewall.firewall.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 200
  action                       = "Allow"

  rule {
    name                       = "Allow Azure DevOps"
    description                = "The VSTS/Azure DevOps agent installed on application VM's requires outbound access. This agent is used by Azure Pipelines for application deployment"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      # https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops
      "*.dev.azure.com",
      "*.pkgs.visualstudio.com",
      "*.visualstudio.com",
      "*.vsassets.io",
      "*.vsblob.visualstudio.com", # Pipeline artifacts
      "*.vsrm.visualstudio.com",
      "*.vstmr.visualstudio.com",
      "*.vssps.visualstudio.com",
      "*.vstmrblob.vsassets.io",
    # "*vsblob*.blob.core.windows.net", # Pipeline artifacts, wildcard not allowed. So instead use:
      "*.blob.core.windows.net", # Pipeline artifacts
      "*.blob.storage.azure.net",
      "dev.azure.com",
      "login.microsoftonline.com",
      "visualstudio-devdiv-c2s.msedge.net",
      "vssps.dev.azure.com",
      "vstsagentpackage.azureedge.net"
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  } 

  # Required traffic originating from within Build / Release jobs e.g. deployment of:
  # AKS, Synapse
  rule {
    name                       = "Allow Pipeline tasks by URL (HTTPS)"
    description                = "Pipeline tasks e.g. Terraform"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      "*.amazonaws.com",
      "*.cloudapp.azure.com", # Application Gateway
      "*.queue.core.windows.net", # Synapse
      "aka.ms",
      "azure.microsoft.com",
      "files.pythonhosted.org",
      "github.com",
      "ipapi.co",
      "ipinfo.io",
      "pypi.org",
      "registry.terraform.io",
      "releases.hashicorp.com",
      "stat.ripe.net",
      "storage.googleapis.com", # kubectl
      "weaveworks.github.io",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  # Required traffic originating from within Build / Release jobs e.g. deployment of:
  # AKS, Synapse
  rule {
    name                       = "Allow Pipeline tasks by URL (HTTP)"
    description                = "Pipeline tasks e.g. curl"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      for location in local.locations : "*${var.dns_host_suffix}.${location}.cloudapp.azure.com"
    ]

    protocol {
      port                     = "80"
      type                     = "Http"
    }
  }

  # rule {
  #   name                       = "Allow Azure SQL Database Pipeline tasks"
  #   description                = "Pipeline tasks e.g. Azure SQL Database"

  #   source_ip_groups           = [
  #     azurerm_ip_group.agents.0.id
  #   ]

  #   target_fqdns               = [
  #     "*.database.windows.net"
  #   ]

  #   protocol {
  #     port                     = "1433"
  #     type                     = "Mssql"
  #   }
  # }  

  rule {
    name                       = "Allow packaging tools"
    description                = "Packaging (e.g. Chocolatey, NuGet) tools"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      "*.chocolatey.org",
      "*.launchpad.net",
      "*.nuget.org",
      "*.powershellgallery.com",
      "*.ubuntu.com",
      "aka.ms",
      "api.npms.io",
      "api.snapcraft.io",
      "baltocdn.com",
      "chocolatey.org",
      "devopsgallerystorage.blob.core.windows.net",
      "download.microsoft.com",
      "launchpad.net",
      "nuget.org",
      "onegetcdn.azureedge.net",
      "packages.cloud.google.com",
      "packages.microsoft.com",
      "psg-prod-eastus.azureedge.net", # PowerShell
      "registry.npmjs.org",
      "skimdb.npmjs.com",
    ]

    protocol {
        port                   = "443"
        type                   = "Https"
    }
  }

  rule {
    name                       = "Allow bootstrap scripts and tools"
    description                = "Bootstrap scripts are hosted on GitHub, tools on their own locations"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      "*.dlservice.microsoft.com",
      "*.github.com",
      "*.githubusercontent.com",
      "*.hashicorp.com",
      "*.pivotal.io",
      "*.smartscreen-prod.microsoft.com",
      "*.typescriptlang.org",
      "*.vo.msecnd.net", # Visual Studio Code
      "azcopy.azureedge.net",
      "azurecliprod.blob.core.windows.net",
      "azuredatastudiobuilds.blob.core.windows.net",
      "dl.pstmn.io", # Postman
      "dl.xamarin.com",
      "download.docker.com",
      "download.elifulkerson.com",
      "download.sysinternals.com",
      "download.visualstudio.com",
      "download.visualstudio.microsoft.com",
      "functionscdn.azureedge.net",
      "get.helm.sh",
      "github-production-release-asset-2e65be.s3.amazonaws.com", 
      "github.com",
      "go.microsoft.com",
      "licensing.mp.microsoft.com",
      "marketplace.visualstudio.com",
      "sqlopsbuilds.azureedge.net", # Data Studio
      "sqlopsextensions.blob.core.windows.net", # Data Studio
      "version.pm2.io",
      "visualstudio.microsoft.com",
      "xamarin-downloads.azureedge.net",
      "visualstudio-devdiv-c2s.msedge.net",
      "wdcp.microsoft.com",
      "wdcpalt.microsoft.com",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  rule {
    name                       = "Allow management traffic by tag"
    description                = "Azure Backup, Diagnostics, Management, Windows Update"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    fqdn_tags                  = [
      "AzureActiveDirectory",
      "AzureBackup",
      "AzureMonitor",
      "MicrosoftActiveProtectionService",
      "WindowsDiagnostics",
      "WindowsUpdate"
    ]
  }

  rule {
    name                       = "Allow management traffic by url"
    description                = "Diagnostics, Management, Windows Update"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      "*.api.cdp.microsoft.com",
      "*.applicationinsights.io",
      "*.azure-automation.net",
      "*.delivery.mp.microsoft.com",
      "*.do.dsp.mp.microsoft.com",
      "*.events.data.microsoft.com",
      "*.identity.azure.net", # MSI Sidecar
      "*.ingestion.msftcloudes.com",
      "*.loganalytics.io",
      "*.microsoftonline-p.com", # AAD Browser login
      "*.monitoring.azure.com",
      "*.msauth.net", # AAD Browser login
      "*.msftauth.net", # AAD Browser login
      "*.msauthimages.net", # AAD Browser login
      "*.msftauthimages.net", # AAD Browser login
      "*.ods.opinsights.azure.com",
      "*.oms.opinsights.azure.com",
      "*.portal.azure.com",
      "*.portal.azure.net", # Portal images, resources
      "*.systemcenteradvisor.com",
      "*.telemetry.microsoft.com",
      "*.update.microsoft.com",
      "*.windowsupdate.com",
      "clientconfig.passport.net",
      "checkappexec.microsoft.com",
      "device.login.microsoftonline.com",
      "edge.microsoft.com",
      "enterpriseregistration.windows.net",
      "graph.microsoft.com",
      "ieonline.microsoft.com",
      "login.microsoftonline.com",
      "management.azure.com",
      "management.core.windows.net",
      "msft.sts.microsoft.com",
      "nav.smartscreen.microsoft.com",
      "opinsightsweuomssa.blob.core.windows.net",
      "pas.windows.net",
      "portal.azure.com",
      "scadvisor.accesscontrol.windows.net",
      "scadvisorcontent.blob.core.windows.net",
      "scadvisorservice.accesscontrol.windows.net",
      "settings-win.data.microsoft.com",
      "smartscreen-prod.microsoft.com",
      "sts.windows.net",
      "urs.microsoft.com",
      "validation-v2.sls.microsoft.com",
      "vortex.data.microsoft.com",
      data.azurerm_storage_account.diagnostics.primary_blob_host,
      data.azurerm_storage_account.diagnostics.primary_table_host
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  rule {
    name                       = "Allow selected HTTP traffic"
    description                = "Plain HTTP traffic for some applications that need it"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

  # https://docs.microsoft.com/en-us/azure/key-vault/general/whats-new#will-this-affect-me
    target_fqdns               = [
      "*.d-trust.net",
      "*.digicert.com",
    # "adl.windows.com",
      "apt.kubernetes.io",
      "archive.ubuntu.com",
      "azure.archive.ubuntu.com",
      "chocolatey.org",
      "crl.microsoft.com",
      "crl.usertrust.com",
      "dl.delivery.mp.microsoft.com", # "Microsoft Edge"
      "go.microsoft.com",
      "ipinfo.io",
      "keyserver.ubuntu.com",
      "mscrl.microsoft.com",
      "ocsp.msocsp.com",
      "ocsp.sectigo.com",
      "ocsp.usertrust.com",
      "oneocsp.microsoft.com",
      "ppa.launchpad.net",
      "security.ubuntu.com",
    # "www.microsoft.com",
      "www.msftconnecttest.com"
    ]

    protocol {
      port                     = "80"
      type                     = "Http"
    }
  }

  count                        = var.use_firewall ? 1 : 0
} 

resource azurerm_firewall_network_rule_collection fw_net_outbound_rules {
  name                         = "${azurerm_firewall.firewall.0.name}-net-out-rules"
  azure_firewall_name          = azurerm_firewall.firewall.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 101
  action                       = "Allow"

  rule {
    name                       = "AllowOutboundDNS"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "53",
    ]
    destination_addresses      = [
      "*",
    ]

    protocols                  = [
      "TCP",
      "UDP",
    ]
  }
  
  rule {
    name                       = "AllowAzureActiveDirectory"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "*",
    ]
    destination_addresses      = [
      "AzureActiveDirectory",
    ]

    protocols                  = [
      "TCP",
      "UDP",
    ]
  }    

  rule {
    name                       = "AllowICMP"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "*",
    ]
    destination_addresses      = [
      "*",
    ]

    protocols                  = [
      "ICMP",
    ]
  }

  rule {
    name                       = "AllowKMS"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "1688",
    ]
    destination_addresses      = [
      "*",
    ]

    protocols                  = [
      "TCP",
    ]
  }

  # keyserver.ubuntu.com 
  rule {
    name                       = "AllowUbuntuKeyServer"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "11371",
    ]
    destination_addresses      = [
      "*",
    ]

    protocols                  = [
      "TCP",
    ]
  }

  rule {
    name                       = "AllowNTP"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "123",
    ]
    destination_addresses      = [
      "*",
    ]

    protocols                  = [
      "UDP",
    ]
  }

  count                        = var.use_firewall ? 1 : 0
}


/*
resource azurerm_firewall_network_rule_collection fw_net_outbound_debug_rules {
  name                         = "${azurerm_firewall.firewall.0.name}-net-out-debug-rules"
  azure_firewall_name          = azurerm_firewall.firewall.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 999
  action                       = "Allow"


  rule {
    name                       = "DEBUGAllowAllOutbound"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "*"
    ]
    destination_addresses      = [
      "*", 
    ]

    protocols                  = [
      "Any"
    ]
  }

  count                        = var.use_firewall ? 1 : 0
}
*/

resource azurerm_monitor_diagnostic_setting firewall_ip_logs {
  name                         = "${azurerm_public_ip.firewall.0.name}-logs"
  target_resource_id           = azurerm_public_ip.firewall.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id
  storage_account_id           = var.diagnostics_storage_id

  log {
    category                   = "DDoSProtectionNotifications"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "DDoSMitigationFlowLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "DDoSMitigationReports"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }

  count                        = var.use_firewall ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting firewall_logs {
  name                         = "${azurerm_firewall.firewall.0.name}-logs"
  target_resource_id           = azurerm_firewall.firewall.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id
  storage_account_id           = var.diagnostics_storage_id

  log {
    category                   = "AzureFirewallDnsProxy"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "AzureFirewallApplicationRule"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  log {
    category                   = "AzureFirewallNetworkRule"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  
  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }

  count                        = var.use_firewall ? 1 : 0
}

resource azurerm_route_table fw_route_table {
  name                         = "${azurerm_firewall.firewall.0.name}-routes"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  route {
    name                       = "VnetLocal"
    address_prefix             = var.address_space
    next_hop_type              = "VnetLocal"
  }
  route {
    name                       = "rfc1918-10"
    address_prefix             = "10.0.0.0/8"
    next_hop_type              = "VnetLocal"
  }
  route {
    name                       = "rfc1918-17"
    address_prefix             = "17.16.0.0/12"
    next_hop_type              = "VnetLocal"
  }
  route {
    name                       = "InternetViaFW"
    address_prefix             = "0.0.0.0/0"
    next_hop_type              = "VirtualAppliance"
    next_hop_in_ip_address     = azurerm_firewall.firewall.0.ip_configuration.0.private_ip_address
  }
  tags                         = var.tags

  count                        = var.use_firewall ? 1 : 0
}

resource azurerm_subnet_route_table_association scale_set_agents {
  subnet_id                    = azurerm_subnet.scale_set_agents.id
  route_table_id               = azurerm_route_table.fw_route_table.0.id

  count                        = var.use_firewall ? 1 : 0
  depends_on                   = [
    azurerm_firewall_application_rule_collection.fw_app_rules,
    azurerm_firewall_network_rule_collection.fw_net_outbound_rules,
    # azurerm_firewall_network_rule_collection.fw_net_outbound_debug_rules,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}
resource azurerm_subnet_route_table_association self_hosted_agents {
  subnet_id                    = azurerm_subnet.self_hosted_agents.id
  route_table_id               = azurerm_route_table.fw_route_table.0.id

  count                        = var.use_firewall ? 1 : 0
  depends_on                   = [
    azurerm_firewall_application_rule_collection.fw_app_rules,
    azurerm_firewall_network_rule_collection.fw_net_outbound_rules,
    # azurerm_firewall_network_rule_collection.fw_net_outbound_debug_rules,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}