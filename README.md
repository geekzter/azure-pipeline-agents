# Azure Pipeline Agents for Private Network Connectivity

[![Build Status](https://dev.azure.com/ericvan/VDC/_apis/build/status/azure-pipeline-agents-ci?branchName=master)](https://dev.azure.com/ericvan/VDC/_build/latest?definitionId=88&branchName=master)

Azure Pipelines includes [Microsoft-hosted Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml) provided by the platform. If you can use these agents I recommend you do so as they provide a complete managed experience.

However, there may be scenarios where you need to manage your own agents:
- Configuration can't be met with any of the hosted agents (e.g. Linux distribution, Windows version)
- Improve build times by caching artifacts
- Network access

The latter point is probably the most common reason to set up your own agents. With the advent of Private Link it is more common to deploy Azure Services so that they can only be access from a virtual network. Hence you need an agent hosting model that fits that requirement. 

<p align="center">
<img src="visuals/diagram.png" width="640">
</p>

## Self-hosted Agents
[Self-hosted Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops) are the predecessor to Scale Set Agents. They also provide the ability to run agents anywhere (including outside Azure). However, you have to manage the full lifecycle of each agent instance. Hence, if you want to go this route, a containerized approach may be better. I still include this approach as a seperate [Terraform module](terraform/modules/self-hosted-agents). It involves installing the VM agent as described on this [page](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux) for Linux. 

In this module, you'll find [install_agent.sh](./scripts/agent/install_agent.sh), which automates the setup:  
`./install_agent.sh  --agent-name debian-agent --agent-pool Default --org myorg --pat <PAT>`  
This will install the agent as systemd (auto start) service.

Likewise, this will install the agent as a service on Windows ([manual setup](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows)):  
`.\install_agent.ps1  -AgentName windows-agent -AgentPool Default -Organization myorg -PAT <PAT>`

Set Terraform variable `use_self_hosted` to `true` (default: `false`) to provision self-hosted agents. You will also need to set `devops_pat` and `devops_org`.

## Scale Set Agents
[Scale Set Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops) leverage Azure Virtual Machine Scale Sets. The lifecycle of individual agents is managed by Azure DevOps, therefore I recommend Scale Set Agents over Self-hosted agents. 

Set Terraform variable `use_scale_set` to `true` (default: `true`) to provision scale set agents. 

The software in the scale set (I use Ubuntu only), is installed using [cloud-init](https://cloudinit.readthedocs.io/en/latest/). 

Note this also sets up some environment variables on the agent e.g. `GEEKZTER_AGENT_VIRTUAL_NETWORK_ID` that can be used in pipelines to set up a peering connection from (see example below).
## Infrastructure Provisioning
### Local
#### Pre-requisites
If you set this up locally, make sure you have the following pre-requisites:
- [Azure CLI](http://aka.ms/azure-cli)
- [PowerShell](https://github.com/PowerShell/PowerShell#get-powershell)
- [Terraform](https://www.terraform.io/downloads.html) (to get that you can use [tfenv](https://github.com/tfutils/tfenv) on Linux & macOS, [Homebrew](https://github.com/hashicorp/homebrew-tap) on macOS or [chocolatey](https://chocolatey.org/packages/terraform) on Windows).

#### Interactive
Use the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) to login:  
`az login`  
`az account set --subscription="SUBSCRIPTION_ID"`

This also [authenticates](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html) the Terraform provider.
You can provision agents by running:  
`terraform init`  
`terraform apply`

#### Scripted
Alternatively, run:  
`./deploy.ps1`

#### Pool
This will perform the  provision the agents. To create a pool from the scale set use the instructions provided [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops#create-the-scale-set-agent-pool).
### From Pipeline
This repo contains a [pipeline](pipelines/azure-pipeline-agents-ci.yml) that can be used for CI/CD. To be able to create Self-Hosted Agents, the 'Project Collection Build Service (org)' group needs to be given 'Administrator' permission to the Agent Pool. For this reason, it is recommended to have a dedicated project for this pipeline.

## Pipeline use
This yaml snippet shows how to reference the scale set pool and use the environment variables set by the agent:

```yaml
pool:
  name: 'Scale Set Agents 1' # Name of the Scale Set Agent Pool you created

steps:
- pwsh: |
    # Use pipeline agent virtual network as VNet to peer from
    $env:TF_VAR_peer_network_id = $env:GEEKZTER_AGENT_VIRTUAL_NETWORK_ID

    # Terraform will use $env:GEEKZTER_AGENT_VIRTUAL_NETWORK_ID as value for input variable 'peer_network_id' 
    # Create on-demand peering... (e.g. https://github.com/geekzter/azure-aks)
```
