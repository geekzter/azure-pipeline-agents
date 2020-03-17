# Self-Hosted Pipeline Agents

Azure Pipelines includes [Self-Hosted Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops) provided by Microsoft. If you can use these agents I recommend you do so as it is a complete managed experience.

However, there may be scenario's where you need to manage your own agent:
- Configuration can't be met with any of the hosted agents (e.g. Linux distribution, Windows version)
- Improve build times by caching artifacts
- Network access

## OS Agent
This [page](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux) describes how to install the Linux Pipeline agent interactively. In this repo, you'll find [install_agent.sh](./scripts/agent/install_agent.sh), which automates the setup:  
`./install_agent.sh  --agent-name debian-agent --agent-pool Default --org myorg --pat <PAT>`  
This will install the agent as systemd (auto start) service

Likewise, this will install the agent as a service on Windows ([manual setup](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows)):  
`.\install_agent.ps1  -AgentName windows-agent -AgentPool Default -Organization myorg -PAT <PAT>`

## Agent Provisioning
Taking it one step further, now you own the agents, you'll probably want to automate their provisioning as well. Using Terraform with the [Azure provider](https://www.terraform.io/docs/providers/azurerm/index.html) that can be automated.

This snippet from [windows.tf](./terraform/windows.tf) illustrates whats involved:

```hcl
resource azurerm_storage_blob install_agent {
  name                         = "install_agent.ps1"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.scripts.name

  type                         = "Block"
  source                       = "../scripts/agent/install_agent.ps1"

  count                        = var.windows_agent_count > 0 ? 1 : 0
}

resource azurerm_windows_virtual_machine windows_agent {
  name                         = "${local.windows_vm_name}${count.index+1}"
  location                     = data.azurerm_resource_group.pipeline_resource_group.location
  resource_group_name          = data.azurerm_resource_group.pipeline_resource_group.name
  network_interface_ids        = [azurerm_network_interface.windows_nic[count.index].id]
  size                         = var.windows_vm_size
  admin_username               = var.user_name
  admin_password               = local.password

  os_disk {
    name                       = "${local.windows_vm_name}${count.index+1}-osdisk"
    caching                    = "ReadWrite"
    storage_account_type       = "Premium_LRS"
  }

  source_image_reference {
    publisher                  = var.windows_os_publisher
    offer                      = var.windows_os_offer
    sku                        = var.windows_os_sku
    version                    = "latest"
  }

  # Required for AAD Login
  identity {
    type                       = "SystemAssigned"
  }

  tags                         = local.tags
  count                        = var.windows_agent_count
}

resource azurerm_virtual_machine_extension pipeline_agent {
  name                         = "PipelineAgentCustomScript"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent[count.index].id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  auto_upgrade_minor_version   = true
  settings                     = <<EOF
    {
      "fileUris": [
                                 "${azurerm_storage_blob.install_agent.0.url}"
      ]
    }
  EOF

  protected_settings           = <<EOF
    { 
      "commandToExecute"       : "powershell.exe -ExecutionPolicy Unrestricted -Command \"./install_agent.ps1 -AgentName ${local.windows_pipeline_agent_name}${count.index+1} -AgentPool ${var.windows_pipeline_agent_pool} -Organization ${var.devops_org} -PAT ${var.devops_pat}\""
    } 
  EOF

  count                        = var.windows_agent_count
}
```
See also [linux.tf](./terraform/linux.tf)  

Now use the [azure cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) to login:  
`az login`  
`az account set --subscription="SUBSCRIPTION_ID"`

This also [authenticates](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html) the Terraform provider.
You can provision agents by running:  
`terraform init`  
`terraform apply`

## Pipeline
The automation would not be complete if we don't run this whole process from an Azure Pipeline. Here is the most relevant task from [azure-pipelines.yml](./azure-pipelines.yml):

```yaml
- task: AzureCLI@2
  displayName: 'Terraforming'
  enabled: true
  inputs:
    azureSubscription: '$(subscriptionConnection)'
    scriptType: pscore
    scriptLocation: inlineScript
    inlineScript: |
      # Use Pipeline Service Principal and Service Connection to configure Terraform azurerm provider
      $env:ARM_CLIENT_ID=$env:servicePrincipalId
      $env:ARM_CLIENT_SECRET=$env:servicePrincipalKey
      $env:ARM_SUBSCRIPTION_ID=(az account show --query id) -replace '"',''
      $env:ARM_TENANT_ID=$env:tenantId

      # Fix case of environment variables mangled by Azure Pipeline Agent
      foreach ($tfvar in $(Get-ChildItem Env:TF_VAR_*)) {
          $properCaseName = $tfvar.Name.Substring(0,7) + $tfvar.Name.Substring(7).ToLowerInvariant()
          Invoke-Expression "`$env:$properCaseName = `$env:$($tfvar.Name)"  
      }
      # List environment variables (debug)
      Get-ChildItem -Path Env: -Recurse -Include ARM_*,AZURE_*,TF_* | Sort-Object -Property Name

      # Terraforming
      terraform init -backend-config=storage_account_name=$(terraformBackendStorageAccount) -backend-config=resource_group_name=$(terraformBackendResourceGroup)
      Write-Host "terraform workspace is '$(terraform workspace show)'"
      if ([System.Convert]::ToBoolean("$(destroyAgentIfExists)")) {
        terraform destroy -auto-approve
      }
      terraform plan -out='agent.plan'
      terraform apply agent.plan
    addSpnToEnvironment: true
    useGlobalConfig: true
    workingDirectory: '$(terraformDirectory)'
    failOnStandardError: true
```

This task provides a setting (`addSpnToEnvironment`) to share the Azure Active Directory Service Principal credentials used for the Azure subscription connection to [authenticate](https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html) the Terraform azurerm provider.


## Limitations
- This does not include any additional software you need to install on the agents