# Azure Pipeline Agents for Private Connectivity

Azure Pipelines includes [Microsoft-hosted Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml) provided by the platform. If you can use these agents I recommend you do so as they provide a complete managed experience.

However, there may be scenarios where you need to manage your own agents:
- Configuration can't be met with any of the hosted agents (e.g. Linux distribution, Windows version)
- Improve build times by caching artifacts
- Network access

The latter point is probably the most common reason to set up your own agents. With the advent of Private Link it is more common to deploy Azure Services do that they can only be access from a virtual network. Hence you need an agent hosting model that fits that requirement. 

![](visuals/diagram.png)

## Self-hosted Agents
[Self-hosted Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops) are the predecessor to Scale Set Agents. They also provide the ability to run agents anywehere (including outside Azure). However, you have to manage to full lifecycle of each agent instance. Hence, if you want to go this route, a containerized approach may be better. I still include this approach as a seperate [Terraform module](terraform/modules/self-hosted-agents). It involves installing the VM agent as described on this [page](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux) for Linux. 

In this module, you'll find [install_agent.sh](./scripts/agent/install_agent.sh), which automates the setup:  
`./install_agent.sh  --agent-name debian-agent --agent-pool Default --org myorg --pat <PAT>`  
This will install the agent as systemd (auto start) service.

Likewise, this will install the agent as a service on Windows ([manual setup](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows)):  
`.\install_agent.ps1  -AgentName windows-agent -AgentPool Default -Organization myorg -PAT <PAT>`

Set Terraform variable `use_self_hosted` to `true` (default: `false`) to provision self-hosted agents. You will also need to set `devops_pat` and `devops_org` in thise case.

## Scale Set Agents
[Scale Set Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops) leverage Azure Virtual Machine Scale Sets. The lifecycle of individual agents is managed my Azure DevOps, therefore I recommend Scale Set Agents over Self-hosted agents. 

Set Terraform variable `use_scale_set` to `true` (default: `true`) to provision scale set agents. 

The software in the scale set (I use Ubuntu only), is installed using [cloud-init](https://cloudinit.readthedocs.io/en/latest/). Here is the yaml used:
```yaml
#cloud-config
bootcmd:
  - sudo apt remove unattended-upgrades -y
  # Prevent race condition with VM extension provisioning
  - while ( fuser /var/lib/dpkg/lock >/dev/null 2>&1 ); do sleep 5; done;
  - while ( fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ); do sleep 5; done;
  # Get apt repository signing keys
  - sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0    # GitHub
  - sudo apt-add-repository https://cli.github.com/packages
  - curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -                  # Helm
  - curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add # Kubernetes
  - curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - # Microsoft

apt:
  sources:
    git-core:
      source: "ppa:git-core/ppa"
    helm-stable-debian.list:
      source: "deb https://baltocdn.com/helm/stable/debian/ all main"
    kubernetes.list:
      source: "deb http://apt.kubernetes.io/ kubernetes-xenial main"
    azure-cli.list:
      source: "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ bionic main"
    microsoft-prod.list:
      source: "deb [arch=amd64] https://packages.microsoft.com/ubuntu/18.04/prod bionic main"

package_update: true
  # Disable package upgrades to get rid of the following error
  #   Could not get lock /var/lib/dpkg/lock-frontend - open (11: Resource temporarily unavailable)
# package_upgrade: true
packages:
  # Core
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - software-properties-common
  # Tools
  - ansible
  - coreutils
  - docker
  - unixodbc-dev
  - unzip
  # Kubernetes
  - helm
  - kubectl
  # Microsoft
  - azure-cli
  - azure-functions-core-tools
  # - blobfuse
  - dotnet-sdk-3.1
  - powershell

runcmd:
  # Microsoft packages
  - sudo ACCEPT_EULA=Y apt install msodbcsql17 -y
  - sudo ACCEPT_EULA=Y apt install mssql-tools -y
  # Automatic updates: re-enable them
  - sudo apt install unattended-upgrades -y

write_files:
- path: /etc/environment
  content: |
    GEEKZTER_AGENT_SUBNET_ID="${subnet_id}"
    GEEKZTER_AGENT_VIRTUAL_NETWORK_ID="${virtual_network_id}"
  append: true

final_message: "Up after $UPTIME seconds"
```

Note this also sets up some environment variables e.g. `GEEKZTER_AGENT_VIRTUAL_NETWORK_ID` that can be used in pipelines to set up a connection from (see example below).
## Infrastructure Provisioning

Use the [azure cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) to login:  
`az login`  
`az account set --subscription="SUBSCRIPTION_ID"`

This also [authenticates](https://www.terraform.io/docs/providers/azurerm/guides/azure_cli.html) the Terraform provider.
You can provision agents by running:  
`terraform init`  
`terraform apply`

This will only provision the scale set. To create a pool from this scale set (AFAIK not automatable) using the instructions [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops#create-the-scale-set-agent-pool).


## Pipeline use
The automation would not be complete if we don't run this whole process from an Azure Pipeline. Here is the most relevant task from [azure-pipelines.yml](./azure-pipelines.yml):

```yaml
pool:
  name: 'Scale Set Agents 1' # Name of the Scale Set Agent Pool you created

steps:
- pwsh: |
    # Use pipeline agent virtual network as VNet to peer from
    $env:TF_VAR_peer_network_id = $env:GEEKZTER_AGENT_VIRTUAL_NETWORK_ID

    # Terraform will use $env:GEEKZTER_AGENT_VIRTUAL_NETWORK_ID as value for input variable 'peer_network_id'
```

