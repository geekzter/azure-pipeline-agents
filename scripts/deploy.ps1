#!/usr/bin/env pwsh

<# 
.SYNOPSIS 
    Deploys Azure resources using Terraform
 
.DESCRIPTION 
    This script is a wrapper around Terraform. It is provided for convenience only, as it works around some limitations in the demo. 
    E.g. terraform might need resources to be started before executing, and resources may not be accessible from the current locastion (IP address).

.EXAMPLE
    ./deploy.ps1 -apply
#> 
#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$false,HelpMessage="Initialize Terraform backend, modules & provider")][switch]$Init=$false,
    [parameter(Mandatory=$false,HelpMessage="Perform Terraform plan stage")][switch]$Plan=$false,
    [parameter(Mandatory=$false,HelpMessage="Perform Terraform validate stage")][switch]$Validate=$false,
    [parameter(Mandatory=$false,HelpMessage="Perform Terraform apply stage (implies plan)")][switch]$Apply=$false,
    [parameter(Mandatory=$false,HelpMessage="Perform Terraform destroy stage")][switch]$Destroy=$false,
    [parameter(Mandatory=$false,HelpMessage="Show Terraform output variables")][switch]$Output=$false,
    [parameter(Mandatory=$false,HelpMessage="Don't show prompts unless something get's deleted that should not be")][switch]$Force=$false,
    [parameter(Mandatory=$false,HelpMessage="Initialize Terraform backend, upgrade modules & provider")][switch]$Upgrade=$false,
    [parameter(Mandatory=$false,HelpMessage="Don't try to set up a Terraform backend if it does not exist")][switch]$NoBackend=$false
) 

### Internal Functions
. (Join-Path $PSScriptRoot functions.ps1)

### Validation
if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
    $tfMissingMessage = "Terraform not found"
    if ($IsWindows) {
        $tfMissingMessage += "`nInstall Terraform e.g. from Chocolatey (https://chocolatey.org/packages/terraform) 'choco install terraform'"
    } else {
        $tfMissingMessage += "`nInstall Terraform e.g. using tfenv (https://github.com/tfutils/tfenv)"
    }
    throw $tfMissingMessage
}

Write-Information $MyInvocation.line 
$script:ErrorActionPreference = "Stop"

$workspace = Get-TerraformWorkspace
$planFile  = "${workspace}.tfplan".ToLower()
$varsFile  = "${workspace}.tfvars".ToLower()
$inAutomation = ($env:TF_IN_AUTOMATION -ieq "true")
if (($workspace -ieq "prod") -and $Force) {
    $Force = $false
    Write-Warning "Ignoring -Force in workspace '${workspace}'"
}

try {
    $tfdirectory = (Get-TerraformDirectory)
    Push-Location $tfdirectory
    AzLogin -DisplayMessages
    # Print version info
    terraform -version

    if ($Init -or $Upgrade) {
        if (!$NoBackend) {
            $backendFile = (Join-Path $tfdirectory backend.tf)
            $backendTemplate = "${backendFile}.sample"
            $newBackend = (!(Test-Path $backendFile))
            $tfbackendArgs = ""
            if ($newBackend) {
                if (!$env:TF_VAR_backend_storage_account -or !$env:TF_VAR_backend_storage_container) {
                    Write-Warning "Environment variables TF_VAR_backend_storage_account and TF_VAR_backend_storage_container must be set when creating a new backend from $backendTemplate"
                    $fail = $true
                }
                if (!($env:TF_VAR_backend_resource_group -or $env:ARM_ACCESS_KEY -or $env:ARM_SAS_TOKEN)) {
                    Write-Warning "Environment variables ARM_ACCESS_KEY or ARM_SAS_TOKEN or TF_VAR_backend_resource_group (with $identity granted 'Storage Blob Data Contributor' role) must be set when creating a new backend from $backendTemplate"
                    $fail = $true
                }
                if ($fail) {
                    Write-Warning "This script assumes Terraform backend exists at ${backendFile}, but it does not exist"
                    Write-Host "You can copy ${backendTemplate} -> ${backendFile} and configure a storage account manually"
                    Write-Host "See documentation at https://www.terraform.io/docs/backends/types/azurerm.html"
                    exit
                }

                # Terraform azurerm backend does not exist, create one
                Write-Host "Creating '$backendFile'"
                Copy-Item -Path $backendTemplate -Destination $backendFile
                
                $tfbackendArgs += " -reconfigure"
            }

            if ($env:TF_VAR_backend_resource_group) {
                $tfbackendArgs += " -backend-config=`"resource_group_name=${env:TF_VAR_backend_resource_group}`""
            }
            if ($env:TF_VAR_backend_storage_account) {
                $tfbackendArgs += " -backend-config=`"storage_account_name=${env:TF_VAR_backend_storage_account}`""
            }
            if ($env:TF_VAR_backend_storage_container) {
                $tfbackendArgs += " -backend-config=`"container_name=${env:TF_VAR_backend_storage_container}`""
            }
        }

        $initCmd = "terraform init $tfbackendArgs"
        if ($Upgrade) {
            $initCmd += " -upgrade"
        }
        Invoke "$initCmd" 
    }

    if ($Validate) {
        Invoke "terraform validate" 
    }
    
    # Prepare common arguments
    if ($Force) {
        $forceArgs = "-auto-approve"
    }

    if (!(Get-ChildItem Env:TF_VAR_* -Exclude TF_VAR_backend_*) -and (Test-Path $varsFile)) {
        # Load variables from file, if it exists and environment variables have not been set
        $varArgs = " -var-file='$varsFile'"
    }

    if ($Apply) {
        # Taint Admin SSH rule(s) so they will be replaced and Terraform can get in to check cloud-init status
        Write-Host "Tainting admin SSH rules to get just-in-time deployment access..."
        terraform state list | Select-String -Pattern "admin_ssh" | foreach-object {
            $resource = ($_ -replace "`"","`\`"")
            Invoke-Expression "terraform taint '$resource'"
        }
    }

    if ($Plan -or $Apply) {
        # FIX: Start VM's to prevent https://github.com/terraform-providers/terraform-provider-azurerm/issues/8311
        $terraformDirectory = (Join-Path (Split-Path -parent -Path $PSScriptRoot) "terraform")
        Push-Location $terraformDirectory
        $resourceGroup = (Get-TerraformOutput resource_group_name)
        if ($resourceGroup) {
            Invoke-Command -ScriptBlock {
                $Private:ErrorActionPreference = "Continue"
                $vms = $(az vm list -d -g $resourceGroup --subscription $env:ARM_SUBSCRIPTION_ID --query "[?powerState!='VM running'].id" -o tsv)
                if ($vms) {
                    Write-Host "Starting VM's in resource group '${resourceGroup}'..."
                    az vm start --ids $vms --no-wait -o none 2>$null
                    az vm start --ids $vms --query "[].name" -o tsv
                }
            }
        }
        Pop-Location

        # Create plan
        Invoke "terraform plan $varArgs -out='$planFile' -var=""script_wrapper_check=false"" "
    }

    if ($Apply) {
        Write-Verbose "Converting $planFile into JSON so we can perform some inspection..."
        $planJSON = (terraform show -json $planFile)

        # Check whether key resources will be replaced
        if (Get-Command jq -ErrorAction SilentlyContinue) {
            $linuxVMsReplaced   = $planJSON | jq -r '.resource_changes[] | select(.address|endswith(\"azurerm_linux_virtual_machine.vm\")) | select( any (.change.actions[];contains(\"delete\"))) | .address'
            $windowsVMsReplaced = $planJSON | jq -r '.resource_changes[] | select(.address|endswith(\"azurerm_windows_virtual_machine.vm\")) | select( any (.change.actions[];contains(\"delete\"))) | .address'
            $vmsReplaced        = (($linuxVMsReplaced + $windowsVMsReplaced) -replace " +","`n")
        } else {
            Write-Warning "jq not found, plan validation skipped. Look at the plan carefully before approving"
            if ($Force) {
                $Force = $false # Ignore force if automated vcalidation is not possible
                Write-Warning "Ignoring -force"
            }
        }

        if (!$inAutomation) {
            if ($vmsReplaced) {
                Write-Warning "You're about to replace these Virtual Machines in workspace '${workspace}':"
                $vmsReplaced
                if ($Force) {
                    $Force = $false # Ignore force if resources with state get replaces
                    Write-Warning "Ignoring -force"
                }
            }

            if (!$Force) {
                # Prompt to continue
                Write-Host "`nIf you wish to proceed executing Terraform plan $planFile in workspace $workspace, please reply 'yes' - null or N aborts" -ForegroundColor Cyan
                $proceedanswer = Read-Host 

                if ($proceedanswer -ne "yes") {
                    Write-Host "`nReply is not 'yes' - Aborting " -ForegroundColor Yellow
                    exit
                }
            }
        }

        Invoke "terraform apply $forceArgs '$planFile'"
    }

    if ($Output) {
        Invoke "terraform output"
    }

    if ($Destroy) {
        Invoke "terraform destroy $varArgs" # $forceArgs"
    }
} finally {
    Pop-Location
}