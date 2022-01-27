#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Installs and Configures Azure Pipeline Agent on Target
#> 
param ( 
    [parameter(Mandatory=$false)][string]$AgentName=$env:COMPUTERNAME,
    [parameter(Mandatory=$true)][string]$AgentPool,
    [parameter(Mandatory=$true)][string]$Organization,
    [parameter(Mandatory=$true)][string]$PAT
) 

if (!$IsWindows -and ($PSVersionTable.PSEdition -ine "Desktop")) {
    Write-Error "This only runs on Windows..."
    exit 1
}

# Run post generation, of available on image
if (Test-Path C:\post-generation) {
    Write-Host "Running port generation..."
    # https://github.com/actions/virtual-environments/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
    Get-ChildItem C:\post-generation -Filter *.ps1 | ForEach-Object { 
        if ($_.FullName -inotmatch "VSConfig|InternetExplorer") {
            Write-Host $_.FullName
            & $_.FullName 
        }
    }
}

#$pipelineDirectory = Join-Path $env:HOME pipeline-agent
$pipelineDirectory = Join-Path $env:ProgramFiles pipeline-agent
$agentService = "vstsagent.${Organization}.${AgentPool}.${AgentName}"
if (Test-Path (Join-Path $pipelineDirectory .agent)) {
    Write-Host "Agent $AgentName already installed, removing first..."
    Push-Location $pipelineDirectory 
    Stop-Service $agentService
    .\config.cmd remove --unattended --auth pat --token $PAT
}

# Get latest released version from GitHub
$agentVersion = $(Invoke-Webrequest -Uri https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest -UseBasicParsing | ConvertFrom-Json | Select-Object -ExpandProperty name) -replace "v",""
$agentPackage = "vsts-agent-win-x64-${agentVersion}.zip"
$agentUrl = "https://vstsagentpackage.azureedge.net/agent/${agentVersion}/${agentPackage}"

if (!(Test-Path $pipelineDirectory)) {
    New-Item -ItemType directory -Path $pipelineDirectory
}
Push-Location $pipelineDirectory 
Write-Host "Retrieving agent from ${agentUrl}..."
Invoke-Webrequest -Uri $agentUrl -OutFile $agentPackage -UseBasicParsing
Write-Host "Extracting ${agentPackage} in ${pipelineDirectory}..."
Expand-Archive -Path $agentPackage -DestinationPath $pipelineDirectory
Write-Host "Extracted ${agentPackage}"

# Use work directory that does not contain spaces, and is located at the designated OS location for data
$pipelineWorkDirectory = "$($env:ProgramData)\pipeline-agent\_work"
$null = New-Item -ItemType Directory -Path $pipelineWorkDirectory -Force

# Unattended config
# https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops#unattended-config
Write-Host "Creating agent ${AgentName} and adding it to pool ${AgentPool} in organization ${Organization}..."
.\config.cmd --unattended `
             --url https://dev.azure.com/${Organization} `
             --auth pat --token $PAT `
             --pool $AgentPool `
             --agent $AgentName --replace `
             --acceptTeeEula `
             --runAsService `
             --windowsLogonAccount "NT AUTHORITY\NETWORK SERVICE" `
             --work $pipelineWorkDirectory

# Start Service
Start-Service $agentService