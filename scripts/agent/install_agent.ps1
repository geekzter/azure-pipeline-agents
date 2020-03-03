#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Installs and Configures Azure Pipeline Agent on Target
#> 
param ( 
    [parameter(Mandatory=$true)][string]$AgentName,
    [parameter(Mandatory=$true)][string]$AgentPool,
    [parameter(Mandatory=$true)][string]$Organization,
    [parameter(Mandatory=$true)][string]$PAT
) 

if (!$IsWindows -and ($PSVersionTable.PSEdition -ine "Desktop")) {
    Write-Error "This only runs on Windows..."
    exit 1
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
$agentVersion = $(Invoke-Webrequest https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | ConvertFrom-Json | Select-Object -ExpandProperty name) -replace "v",""
$agentPackage = "vsts-agent-win-x64-${agentVersion}.zip"
$agentUrl = "https://vstsagentpackage.azureedge.net/agent/${agentVersion}/${agentPackage}"

if (!(Test-Path $pipelineDirectory)) {
    New-Item -ItemType directory -Path $pipelineDirectory
}
Push-Location $pipelineDirectory 
Write-Host "Retrieving agent from ${agentUrl}..."
Invoke-Webrequest $agentUrl -OutFile $agentPackage
Write-Host "Extracting ${agentPackage} in ${pipelineDirectory}..."
Expand-Archive -Path $agentPackage -DestinationPath $pipelineDirectory
Write-Host "Extracted ${agentPackage}"

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
             --windowsLogonAccount "NT AUTHORITY\NETWORK SERVICE" 

# Start Service
Start-Service $agentService