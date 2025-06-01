resource azurerm_subnet fw_subnet {
  name                         = "AzureFirewallSubnet"
  virtual_network_name         = azurerm_virtual_network.pipeline_network.name
  resource_group_name          = azurerm_virtual_network.pipeline_network.resource_group_name
  address_prefixes             = [cidrsubnet(tolist(azurerm_virtual_network.pipeline_network.address_space)[0],4,0)]
  default_outbound_access_enabled = false

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_ip_group agents {
  name                         = "agents-ip-group"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = concat(azurerm_subnet.scale_set_agents.address_prefixes,azurerm_subnet.self_hosted_agents.address_prefixes)

  tags                         = var.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_ip_group packer {
  name                         = "packer-ip-group"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = [var.packer_address_space]

  tags                         = var.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_ip_group vnet {
  name                         = "vnets-ip-group"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = [
    var.address_space,
    var.packer_address_space
  ]

  tags                         = var.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_ip_group ado {
  name                         = "ado-ip-group"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = [
    # https://docs.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#ip-addresses-and-range-restrictions
    "13.107.6.0/24",
    "13.107.9.0/24",
    "13.107.42.0/24",
    "13.107.43.0/24",
  ]

  tags                         = var.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_ip_group microsoft_365 {
  name                         = "microsoft365-ip-group"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  cidrs                        = [
    # https://docs.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#other-ip-addresses
    "40.82.190.38",
    "52.108.0.0/14",
    "52.237.19.6",
    "52.238.106.116/32",
    "52.244.37.168/32",
    "52.244.203.72/32",
    "52.244.207.172/32",
    "52.244.223.198/32",
    "52.247.150.191/32",
  ]

  tags                         = var.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_public_ip firewall {
  name                         = "${var.resource_group_name}-fw-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.deploy_firewall ? 1 : 0

  # provisioner local-exec {
  #   # BUG: https://github.com/hashicorp/terraform-provider-azurerm/issues/14966
  #   when                       = destroy
  #   command                    = "az network firewall delete --ids ${self.id}"
  # }
}

resource azurerm_firewall firewall {
  name                         = "${var.resource_group_name}-fw"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  sku_name                     = "AZFW_VNet"
  sku_tier                     = "Standard"

  dns_servers                  = ["168.63.129.16"] # Azure DNS

  ip_configuration {
    name                       = "fw_ipconfig"
    subnet_id                  = azurerm_subnet.fw_subnet.0.id
    public_ip_address_id       = azurerm_public_ip.firewall.0.id
  }

  tags                         = var.tags

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_virtual_network_dns_servers dns_proxy {
  virtual_network_id           = azurerm_virtual_network.pipeline_network.id
  dns_servers                  = [azurerm_firewall.firewall.0.ip_configuration.0.private_ip_address]

  count                        = var.deploy_firewall && var.enable_firewall_dns_proxy ? 1 : 0
}

# Outbound domain whitelisting
resource azurerm_firewall_application_rule_collection agent_app_rules {
  name                         = "${azurerm_firewall.firewall.0.name}-agent-app-rules"
  azure_firewall_name          = azurerm_firewall.firewall.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 200
  action                       = "Allow"

  rule {
    name                       = "Allow management traffic by tag (config:${var.configuration_name})"
    description                = "Azure Backup, Diagnostics, Management, Windows Update"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    fqdn_tags                  = [
      "AzureActiveDirectory",
      "AzureBackup",
      "AzureMonitor",
      "AzureUpdateDelivery",
      "GuestAndHybridManagement",
      "MicrosoftActiveProtectionService",
      "WindowsAdminCenter",
      "WindowsDiagnostics",
      "WindowsUpdate"
    ]
  }

  rule {
    name                       = "Allow management traffic by url (config:${var.configuration_name})"
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
      "*.guestconfiguration.azure.com",
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
      "*.telecommandsvc.microsoft.com",
      "*.telemetry.microsoft.com",
      "*.update.microsoft.com",
      "*.windowsupdate.com",
      "clientconfig.passport.net",
      "checkappexec.microsoft.com",
      "contracts.canonical.com",
      "device.login.microsoftonline.com",
      "dmd.metaservices.microsoft.com",
      "edge.microsoft.com",
      "enterpriseregistration.windows.net",
      "entropy.ubuntu.com",
      "graph.microsoft.com",
      "ieonline.microsoft.com",
      "login.microsoftonline.com",
      "management.azure.com",
      "management.core.windows.net",
      "motd.ubuntu.com",
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
    name                       = "Allow bootstrap & packaging tools (config:${var.configuration_name})"
    description                = "Packaging (e.g. Chocolatey, NuGet) tools. Bootstrap scripts are hosted on GitHub, tools on their own locations"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      "*.chocolatey.org",
      "*.dlservice.microsoft.com",
      "*.github.com",
      "*.githubusercontent.com",
      "*.hashicorp.com",
      "*.launchpad.net",
      "*.nuget.org",
      "*.pivotal.io",
      "*.powershellgallery.com",
      "*.smartscreen-prod.microsoft.com",
      "*.typescriptlang.org",
      "*.ubuntu.com",
      "*.vo.msecnd.net", # Visual Studio Code
      "aka.ms",
      "api.npms.io",
      "api.snapcraft.io",
      "azcopy.azureedge.net",
      "azcopyvnext.azureedge.net",
      "azurecliprod.blob.core.windows.net",
      "azuredatastudiobuilds.blob.core.windows.net",
      "baltocdn.com",
      "chocolatey.org",
      "devopsgallerystorage.blob.core.windows.net",
      "dl.pstmn.io", # Postman
      "dl.xamarin.com",
      "download.docker.com",
      "download.elifulkerson.com",
      "download.microsoft.com",
      "download.sysinternals.com",
      "download.visualstudio.com",
      "download.visualstudio.microsoft.com",
      "functionscdn.azureedge.net",
      "get.helm.sh",
      "github-production-release-asset-2e65be.s3.amazonaws.com", 
      "github.com",
      "go.microsoft.com",
      "launchpad.net",
      "licensing.mp.microsoft.com",
      "marketplace.visualstudio.com",
      "nuget.org",
      "onegetcdn.azureedge.net",
      "packages.cloud.google.com",
      "packages.efficios.com",
      "packages.microsoft.com",
      "psg-prod-eastus.azureedge.net", # PowerShell
      "registry.npmjs.org",
      "skimdb.npmjs.com",
      "sqlopsbuilds.azureedge.net", # Data Studio
      "sqlopsextensions.blob.core.windows.net", # Data Studio
      "version.pm2.io",
      "visualstudio-devdiv-c2s.msedge.net",
      "visualstudio.microsoft.com",
      "wdcp.microsoft.com",
      "wdcpalt.microsoft.com",
      "xamarin-downloads.azureedge.net",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  rule {
    name                       = "Allow bootstrap & packaging tools (HTTP) (config:${var.configuration_name})"
    description                = "Plain HTTP traffic for some applications that need it"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      "apt.kubernetes.io",
      "archive.ubuntu.com",
      "azure.archive.ubuntu.com",
      "chocolatey.org",
      "dl.delivery.mp.microsoft.com", # "Microsoft Edge"
      "go.microsoft.com",
      "keyserver.ubuntu.com",
      "ppa.launchpad.net",
      "security.ubuntu.com",
      "www.msftconnecttest.com"
    ]

    protocol {
      port                     = "80"
      type                     = "Http"
    }
  }

  dynamic "rule" {
    for_each = range(var.configure_crl_oscp_rules ? 1 : 0) 
    content {
      name                     = "Allow TLS CRL & OSCP (HTTP) (config:${var.configuration_name})"
      description              = "Plain HTTP traffic for Certificate Revocation List (CRL) download and/or Online Certificate Status Protocol locations"

      source_ip_groups         = [
        azurerm_ip_group.agents.0.id
      ]

    # https://docs.microsoft.com/en-us/azure/security/fundamentals/tls-certificate-changes
      target_fqdns             = [
        "*.d-trust.net",
        "*.digicert.com",
        "crl.microsoft.com",
        "crl.usertrust.com",
        "mscrl.microsoft.com",
        "ocsp.msocsp.com",
        "ocsp.sectigo.com",
        "ocsp.usertrust.com",
        "oneocsp.microsoft.com",
        "www.microsoft.com",
      ]

      protocol {
        port                   = "80"
        type                   = "Http"
      }
    }
  }  

  dynamic "rule" {
    for_each = range(var.configure_wildcard_allow_rules ? 1 : 0) 
    content {
      name                     = "Allow Azure VM Guest Agent (wildcard) (config:${var.configuration_name})"

      source_ip_groups         = [
        azurerm_ip_group.agents.0.id
      ]

      # e.g. md-sc4xrwvm2tv5.z36.blob.storage.azure.net
      # StatusUploadBlob(Url)
      # ArtifactsProfileBlob(Url)
      # Guest Agent manifest Uris
      target_fqdns             = [
        "*.blob.storage.azure.net",
      ]

      protocol {
        port                   = "443"
        type                   = "Https"
      }
    }
  }

  dynamic "rule" {
    for_each = range(var.azdo_org != null && var.azdo_org != "" ? 1 : 0) 
    content {
      name                     = "Allow Azure DevOps Organization (config:${var.configuration_name})"

      source_ip_groups         = [
        azurerm_ip_group.agents.0.id
      ]

      target_fqdns             = [
        "${var.azdo_org}.pkgs.visualstudio.com",
        "${var.azdo_org}.visualstudio.com",
        "${var.azdo_org}.vsblob.visualstudio.com",
        "${var.azdo_org}.vsrm.visualstudio.com",
        "${var.azdo_org}.vssps.visualstudio.com",
        "${var.azdo_org}.vstmr.visualstudio.com",
      ]

      protocol {
        port                   = "443"
        type                   = "Https"
      }
    }
  }

  rule {
    name                       = "Allow Azure DevOps (config:${var.configuration_name})"
    description                = "The VSTS/Azure DevOps agent installed on application VM's requires outbound access. This agent is used by Azure Pipelines for application deployment"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
      # https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops#im-running-a-firewall-and-my-code-is-in-azure-repos-what-urls-does-the-agent-need-to-communicate-with
      "*.dev.azure.com",
      "*.pkgs.visualstudio.com",
      "*.visualstudio.com",
      "*.vsassets.io",
      "*.vsblob.visualstudio.com", # Pipeline artifacts
      "*.vsrm.visualstudio.com",
      "*.vssps.visualstudio.com",
      "*.vstmr.visualstudio.com",
      "*.vstmrblob.vsassets.io",
      "api.github.com",
      "app.vssps.visualstudio.com",
      "dev.azure.com",
      "download.agent.dev.azure.com",
      "login.microsoftonline.com",
      "visualstudio-devdiv-c2s.msedge.net",
      "vssps.dev.azure.com",
      "vstsagentpackage.azureedge.net",
      "vstsagenttools.blob.core.windows.net",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  } 

  dynamic "rule" {
    for_each = range(var.configure_wildcard_allow_rules ? 1 : 0) 
    content {
      name                     = "Allow Azure DevOps Artifacts (wildcard) (config:${var.configuration_name})"

      source_ip_groups         = [
        azurerm_ip_group.agents.0.id
      ]

      target_fqdns             = [
        # https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops#im-running-a-firewall-and-my-code-is-in-azure-repos-what-urls-does-the-agent-need-to-communicate-with
        "*.blob.core.windows.net", # Pipeline artifacts *vsblob*.blob.core.windows.net
      ]

      protocol {
        port                   = "443"
        type                   = "Https"
      }
    }
  }

  # # HACK: Try to guess the FQDN's needed, and workaround the Azure Firewall limitation of the asterisk needed at either end of the wildcard expression
  # rule {
  #   name                       = "Allow Azure DevOps Artifacts (config:${var.configuration_name})"

  #   source_ip_groups           = [
  #     azurerm_ip_group.agents.0.id
  #   ]

  #   target_fqdns               = [
  #     for i in range(1024,1,1) : format("*blobprodeus%d.blob.core.windows.net", i)
  #   ]

  #   protocol {
  #     port                     = "443"
  #     type                     = "Https"
  #   }
  # } 


  # Required traffic originating from within Build / Release jobs e.g. deployment of:
  # AKS, Synapse
  rule {
    name                       = "Allow Pipeline tasks by URL (HTTPS) (config:${var.configuration_name})"
    description                = "Pipeline tasks e.g. Terraform"

    source_ip_groups           = [
      azurerm_ip_group.agents.0.id
    ]

    target_fqdns               = [
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

  dynamic "rule" {
    for_each = range(var.configure_wildcard_allow_rules ? 1 : 0) 
    content {
      name                       = "Allow Pipeline tasks by URL wildcard (HTTPS) (config:${var.configuration_name})"
      description                = "Cloud Services e.g. Azure App Service"

      source_ip_groups           = [
        azurerm_ip_group.agents.0.id
      ]

      target_fqdns               = [
        "*.amazonaws.com",
        "*.azurewebsites.net", # App Service
        "*.cloudapp.azure.com", # Application Gateway
        "*.queue.core.windows.net", # Synapse
      ]

      protocol {
        port                     = "443"
        type                     = "Https"
      }
    }
  }  

  # Required traffic originating from within Build / Release jobs e.g. deployment of:
  # AKS, Synapse
  rule {
    name                       = "Allow Pipeline tasks by URL (HTTP) (config:${var.configuration_name})"
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

  dynamic "rule" {
    for_each = range(var.configure_wildcard_allow_rules ? 1 : 0) 
    content {
      name                     = "Allow Azure SQL Database Pipeline tasks (wildcard) (config:${var.configuration_name})"
      description              = "Pipeline tasks e.g. Azure SQL Database (SQL DB proxy mode required)"

      source_ip_groups         = [
        azurerm_ip_group.agents.0.id
      ]

      target_fqdns             = [
        "*.database.windows.net"
      ]

      protocol {
        port                   = "1433"
        type                   = "Mssql"
      }
    }
  }  

  count                        = var.deploy_firewall ? 1 : 0
} 

resource azurerm_firewall_application_rule_collection packer_app_rules {
  name                         = "${azurerm_firewall.firewall.0.name}-packer-app-rules"
  azure_firewall_name          = azurerm_firewall.firewall.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 201
  action                       = "Allow"

  rule {
    name                       = "Allow Known HTTPS (config:${var.configuration_name})"

    source_ip_groups           = [
      azurerm_ip_group.packer.0.id
    ]

    target_fqdns               = [
      "*.cloudfront.net",
      "adoptopenjdk.jfrog.io",
      "aka.ms",
      "api.github.com",
      "api.nuget.org",
      "api.pulumi.com",
      "api.snapcraft.io",
      "apt.postgresql.org",
      "auth.docker.io",
      "awscli.amazonaws.com",
      "azcliextensionsync.blob.core.windows.net",
      "azcopyvnext.azureedge.net",
      "azcopyvnextrelease.blob.core.windows.net",
      "azure.microsoft.com",
      "azurecliprod.blob.core.windows.net",
      "bbuseruploads.s3.amazonaws.com",
      "binaries.erlang-solutions.com",
      "bitbucket.org",
      "cdn.mysql.com",
      "changelogs.ubuntu.com",
      "checkpoint-api.hashicorp.com",
      "chromedriver.storage.googleapis.com",
      "cli-assets.heroku.com",
      "cloud.r-project.org",
      "composer.github.io",
      "crates.io",
      "dc.services.visualstudio.com",
      "dl.google.com",
      "dl.hhvm.com",
      "dl.k8s.io",
      "dotnetcli.blob.core.windows.net",
      "download.microsoft.com",
      "download.mono-project.com",
      "download.opensuse.org",
      "download.swift.org",
      "downloads.apache.org",
      "downloads.gradle-dn.com",
      "downloads.haskell.org",
      "downloads.mysql.com",
      "downloads.python.org",
      "entropy.ubuntu.com",
      "files.pythonhosted.org",
      "get-ghcup.haskell.org",
      "get.haskellstack.org",
      "get.helm.sh",
      "get.pulumi.com",
      "getcomposer.org",
      "ghcr.io",
      "github.com",
      "go.microsoft.com",
      "jfrog-prod-usw2-shared-oregon-main.s3.amazonaws.com",
      "julialang-s3.julialang.org",
      "keyserver.ubuntu.com",
      "launchpad.net",
      "mirror.openshift.com",
      "mirrorcache-us.opensuse.org",
      "mirrorcache.opensuse.org",
      "nodejs.org",
      "objects.githubusercontent.com",
      "oca.opensource.oracle.com",
      "omahaproxy.appspot.com",
      "packagecloud.io",
      "packages.adoptium.net",
      "packages.cloud.google.com",
      "packages.microsoft.com",
      "phar.phpunit.de",
      "pkg-containers.githubusercontent.com",
      "production.cloudflare.docker.com",
      "provo-mirror.opensuse.org",
      "psg-prod-eastus.azureedge.net",
      "pypi.org",
      "pypi.python.org",
      "raw.githubusercontent.com",
      "rdfepirv2dm1prdstr01.blob.core.windows.net",
      "rdfepirv2dm1prdstr03.blob.core.windows.net",
      "rdfepirv2dm1prdstr04.blob.core.windows.net",
      "rdfepirv2dm1prdstr07.blob.core.windows.net",
      "rdfepirv2dm1prdstr08.blob.core.windows.net",
      "registry-1.docker.io",
      "registry.npmjs.org",
      "releases.bazel.build",
      "releases.hashicorp.com",
      "repo.anaconda.com",
      "repo.continuum.io",
      "repo.mongodb.org",
      "repo1.maven.org",
      "repos.azul.com",
      "rubygems.org",
      "s3.amazonaws.com",
      "services.gradle.org",
      "sh.rustup.rs",
      "static.crates.io",
      "static.rust-lang.org",
      "storage.googleapis.com",
      "swift.org",
      "www-eu.apache.org",
      "www.google-analytics.com",
      "www.googleapis.com",
      "www.graalvm.org",
      "www.mongodb.org",
      "www.postgresql.org",
      "www.powershellgallery.com",
      "www.pulumi.com",
      "www.swift.org",
    ]

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

rule {
    name                       = "Allow Known HTTP (config:${var.configuration_name})"

    source_ip_groups           = [
      azurerm_ip_group.packer.0.id
    ]

    target_fqdns               = [
      "azure.archive.ubuntu.com",
      "keyserver.ubuntu.com",
      "ppa.launchpad.net",
      "security.ubuntu.com",
      "www.cpan.org"
    ]

    protocol {
      port                     = "80"
      type                     = "Http"
    }
  }

  rule {
    name                       = "Allow All HTTP(S) (config:${var.configuration_name})"

    source_ip_groups           = [
      azurerm_ip_group.packer.0.id
    ]

    target_fqdns               = [
      "*"
    ]

    protocol {
      port                     = "80"
      type                     = "Http"
    }

    protocol {
      port                     = "443"
      type                     = "Https"
    }
  }

  count                        = var.deploy_firewall ? 1 : 0
} 

resource azurerm_firewall_network_rule_collection vnet_net_outbound_rules {
  name                         = "${azurerm_firewall.firewall.0.name}-net-out-rules"
  azure_firewall_name          = azurerm_firewall.firewall.0.name
  resource_group_name          = var.resource_group_name
  priority                     = 201
  action                       = "Allow"

  dynamic "rule" {
    for_each = range(var.configure_cidr_allow_rules ? 1 : 0) 
    content {
      name                     = "Allow Azure DevOps (config:${var.configuration_name})"

      source_ip_groups         = [
        azurerm_ip_group.agents.0.id
      ]

      destination_ports        = [
        "443",
      ]
      destination_ip_groups    = [
        # https://docs.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#ip-addresses-and-range-restrictions
        azurerm_ip_group.ado.0.id,
        # https://docs.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#other-ip-addresses
        azurerm_ip_group.microsoft_365.0.id,
      ]

      protocols                = [
        "TCP",
      ]
    }
  }
  
  rule {
    name                       = "Allow DNS (config:${var.configuration_name})"

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
    name                       = "Allow Azure Active Directory (config:${var.configuration_name})"

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
    name                       = "Allow Git SSH"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "22"
    ]
    destination_fqdns          = [
      "github.com", 
      "ssh.dev.azure.com",
      "vs-ssh.visualstudio.com"
    ]

    protocols                  = [
      "TCP"
    ]
  }

  rule {
    name                       = "Allow ICMP (config:${var.configuration_name})"

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
    name                       = "Allow KMS (config:${var.configuration_name})"

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
    name                       = "Allow Ubuntu OpenPGP Key Server (config:${var.configuration_name})"

    source_ip_groups           = [
      azurerm_ip_group.vnet.0.id
    ]

    destination_ports          = [
      "11371",
    ]
    destination_fqdns          = [
      "keyserver.ubuntu.com", 
    ]

    protocols                  = [
      "TCP",
    ]
  }

  rule {
    name                       = "Allow NTP (config:${var.configuration_name})"

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

  count                        = var.deploy_firewall ? 1 : 0
}

# resource azurerm_firewall_network_rule_collection agent_allow_all_outbound {
#   name                         = "${azurerm_firewall.firewall.0.name}-agent-net-out-debug-rules"
#   azure_firewall_name          = azurerm_firewall.firewall.0.name
#   resource_group_name          = var.resource_group_name
#   priority                     = 999
#   action                       = "Allow"


#   rule {
#     name                       = "Allow All Outbound (DEBUG) (config:${var.configuration_name})"

#     source_ip_groups           = [
#       azurerm_ip_group.vnet.0.id
#     ]

#     destination_ports          = [
#       "*"
#     ]
#     destination_addresses      = [
#       "*", 
#     ]

#     protocols                  = [
#       "Any"
#     ]
#   }

#   count                        = var.deploy_firewall ? 1 : 0
# }

# resource azurerm_firewall_network_rule_collection packer_net_rules {
#   name                         = "${azurerm_firewall.firewall.0.name}-packer-net-out-rules"
#   azure_firewall_name          = azurerm_firewall.firewall.0.name
#   resource_group_name          = var.resource_group_name
#   priority                     = 998
#   action                       = "Allow"

#   rule {
#     name                       = "Allow All Outbound (DEBUG) (config:${var.configuration_name})"

#     source_ip_groups           = [
#       azurerm_ip_group.packer.0.id
#     ]

#     destination_ports          = [
#       "*"
#     ]
#     destination_addresses      = [
#       "*", 
#     ]

#     protocols                  = [
#       "Any"
#     ]
#   }

#   count                        = var.deploy_firewall ? 1 : 0
# }

resource azurerm_monitor_diagnostic_setting firewall_ip_logs {
  name                         = "${azurerm_public_ip.firewall.0.name}-logs"
  target_resource_id           = azurerm_public_ip.firewall.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id
  storage_account_id           = var.diagnostics_storage_id

  enabled_log {
    category                   = "DDoSProtectionNotifications"
  }

  enabled_log {
    category                   = "DDoSMitigationFlowLogs"
  }

  enabled_log {
    category                   = "DDoSMitigationReports"
  }

  enabled_metric {
    category                   = "AllMetrics"
  }

  count                        = var.deploy_firewall ? 1 : 0
}

resource azurerm_monitor_diagnostic_setting firewall_logs {
  name                         = "${azurerm_firewall.firewall.0.name}-logs"
  target_resource_id           = azurerm_firewall.firewall.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_resource_id
  storage_account_id           = var.diagnostics_storage_id

  enabled_log {
    category                   = "AzureFirewallDnsProxy"

  }

  enabled_log {
    category                   = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category                   = "AzureFirewallNetworkRule"
  }
  
  enabled_metric {
    category                   = "AllMetrics"
  }

  count                        = var.deploy_firewall ? 1 : 0
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

  count                        = var.deploy_firewall ? 1 : 0
}
# FIX: Error: deleting Route Table "azure-pipelines-agents-ci-99999b-fw-routes" (Resource Group "azure-pipelines-agents-ci-99999b"): network.RouteTablesClient#Delete: Failure sending request: StatusCode=400 -- Original Error: Code="InUseRouteTableCannotBeDeleted" Message="Route table azure-pipelines-agents-ci-99999b-fw-routes is in use and cannot be deleted." Details=[]
resource time_sleep fw_route_table_destroy_race_condition {
  depends_on                   = [azurerm_route_table.fw_route_table]
  destroy_duration             = "${var.destroy_wait_minutes}m"
}

resource azurerm_subnet_route_table_association scale_set_agents {
  subnet_id                    = azurerm_subnet.scale_set_agents.id
  route_table_id               = azurerm_route_table.fw_route_table.0.id

  count                        = var.deploy_firewall ? 1 : 0
  depends_on                   = [
    azurerm_firewall_application_rule_collection.agent_app_rules,
    azurerm_firewall_application_rule_collection.packer_app_rules,
    azurerm_firewall_network_rule_collection.vnet_net_outbound_rules,
    # azurerm_firewall_network_rule_collection.agent_allow_all_outbound,
    # azurerm_firewall_network_rule_collection.packer_allow_all_outbound,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}
resource azurerm_subnet_route_table_association self_hosted_agents {
  subnet_id                    = azurerm_subnet.self_hosted_agents.id
  route_table_id               = azurerm_route_table.fw_route_table.0.id

  count                        = var.deploy_firewall ? 1 : 0
  depends_on                   = [
    azurerm_firewall_application_rule_collection.agent_app_rules,
    azurerm_firewall_application_rule_collection.packer_app_rules,
    azurerm_firewall_network_rule_collection.vnet_net_outbound_rules,
    # azurerm_firewall_network_rule_collection.agent_allow_all_outbound,
    # azurerm_firewall_network_rule_collection.packer_allow_all_outbound,
    azurerm_monitor_diagnostic_setting.firewall_logs,
  ]
}