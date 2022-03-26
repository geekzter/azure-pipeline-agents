#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Installs and Configures Azure Pipeline Agent on Target
#> 
param ( 
    [parameter(Mandatory=$false)][string]$AgentName=$env:COMPUTERNAME,
    [parameter(Mandatory=$true)][string]$AgentPool,
    [parameter(Mandatory=$true)][string]$AgentVersionId="latest",
    [parameter(Mandatory=$true)][string]$Organization,
    [parameter(Mandatory=$true)][string]$PAT
) 
$ProgressPreference = 'SilentlyContinue' # Improves batch performance in Windows PowerShell

if (!$IsWindows -and ($PSVersionTable.PSEdition -ine "Desktop")) {
    Write-Error "This only runs on Windows..."
    exit 1
}

# Run post generation, of available on image
if (Test-Path C:\post-generation) {
    # https://github.com/actions/virtual-environments/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
    Get-ChildItem C:\post-generation -Filter *.ps1 | ForEach-Object { 
        if ($_.FullName -inotmatch "VSConfig|InternetExplorer") {
            Write-Host $_.FullName
            & $_.FullName 
        }
    }
}

# Set environment variables
%{ for name, value in environment }
    [Environment]::SetEnvironmentVariable("${name}", "${value}", "Machine")
%{ endfor ~}

# Mount file share
if ("${smb_share}") {
    if (!(Get-Command New-SmbGlobalMapping -ErrorAction SilentlyContinue)) {
        Write-Warning "Command 'New-SmbGlobalMapping' not found. Agent diagnostics will be stored locally."
        exit
    }

    $connectTestResult = Test-NetConnection -ComputerName ${storage_share_host} -Port 445
    if (!$connectTestResult.TcpTestSucceeded) {
        Write-Error -Message "Unable to reach '${storage_share_host}' via port 445."
    }

    ConvertTo-SecureString -String "${storage_account_key}" -AsPlainText -Force | Set-Variable storageKey
    New-Object System.Management.Automation.PSCredential -ArgumentList "AZURE\${storage_account_name}", $storageKey | Set-Variable credential 
    New-SmbGlobalMapping -RemotePath "${smb_share}" -Credential $credential -LocalPath ${drive_letter}: -FullAccess @( "NT AUTHORITY\SYSTEM", "${user_name}" ) -Persistent $true #-UseWriteThrough

    # Link agent diagnostics directory
    Join-Path ${drive_letter}:\ $env:COMPUTERNAME | Set-Variable diagnosticsSMBDirectory
    New-Item -ItemType directory -Path $diagnosticsSMBDirectory -Force
    if (!(Test-Path $diagnosticsSMBDirectory)) {
        "'{0}' not found, has share {1} been mounted on {2}:?" -f $diagnosticsSMBDirectory, "${smb_share}", "${drive_letter}" | Write-Error
    }
    New-Item -ItemType symboliclink -Path "${diagnostics_directory}" -Value "$diagnosticsSMBDirectory" -Force
    $pipelineDiagnosticsDirectory = "${diagnostics_directory}"
}

$pipelineDirectory = Join-Path $env:ProgramFiles pipeline-agent
"vstsagent.{0}.{1}.{2}" -f $Organization, $AgentPool, $AgentName | Set-Variable agentService
if (Test-Path (Join-Path $pipelineDirectory .agent)) {
    Write-Host "Agent $AgentName already installed, removing first..."
    Push-Location $pipelineDirectory 
    Stop-Service $agentService
    .\config.cmd remove --unattended --auth pat --token $PAT
}

# Get desired release version from GitHub
"https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/{0}" -f $AgentVersionId | Set-Variable agentReleaseUrl
$agentVersion = $(Invoke-Webrequest -Uri $agentReleaseUrl -UseBasicParsing | ConvertFrom-Json | Select-Object -ExpandProperty name) -replace "v",""
"vsts-agent-win-x64-{0}.zip" -f $agentVersion | Set-Variable agentPackage
"https://vstsagentpackage.azureedge.net/agent/{0}/{1}" -f $agentVersion, $agentPackage | Set-Variable agentUrl

if (!(Test-Path $pipelineDirectory)) {
    New-Item -ItemType directory -Path $pipelineDirectory
}
Push-Location $pipelineDirectory 
Write-Host "Retrieving agent from $agentUrl..."
Invoke-Webrequest -Uri $agentUrl -OutFile $agentPackage -UseBasicParsing
Write-Host "Extracting $agentPackage in $pipelineDirectory..."
Expand-Archive -Path $agentPackage -DestinationPath $pipelineDirectory
Write-Host "Extracted $agentPackage"

# Use work directory that does not contain spaces, and is located at the designated OS location for data
$pipelineWorkDirectory = "$($env:ProgramData)\pipeline-agent\work"
$null = New-Item -ItemType Directory -Path $pipelineWorkDirectory -Force
$null = New-Item -ItemType symboliclink -path "$pipelineDirectory\_work" -value "$pipelineWorkDirectory" -Force
if (!$pipelineDiagnosticsDirectory -or !(Test-Path $pipelineDiagnosticsDirectory)) {
    $pipelineDiagnosticsDirectory = "$($env:ProgramData)\pipeline-agent\diag"
}
$null = New-Item -ItemType Directory -Path $pipelineDiagnosticsDirectory -Force
$null = New-Item -ItemType symboliclink -path "$pipelineDirectory\_diag" -value "$pipelineDiagnosticsDirectory" -Force

# Unattended config
# https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops#unattended-config
Write-Host "Creating agent $AgentName and adding it to pool $AgentPool in organization $Organization..."
.\config.cmd --unattended `
             --url https://dev.azure.com/$Organization `
             --auth pat --token $PAT `
             --pool $AgentPool `
             --agent $AgentName --replace `
             --acceptTeeEula `
             --runAsService `
             --windowsLogonAccount "NT AUTHORITY\NETWORK SERVICE" `
             --work $pipelineWorkDirectory

# Start Service
Start-Service $agentService