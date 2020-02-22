#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$false)][switch]$Enabled,
    [parameter(Mandatory=$false)][string]$AgentName,
    [parameter(Mandatory=$false)][string]$AgentPoolName,
    [parameter(Mandatory=$false)][string]$OrganizationUrl=$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI,
    #[parameter(Mandatory=$false)][string]$Project,
    [parameter(Mandatory=$false)][string]$Token=$env:AZURE_DEVOPS_EXT_PAT
) 

Write-Host "DebugPreference: $DebugPreference"

# List environment variables (debug)
if ($DebugPreference -ine "SilentlyContinue") {
    Get-ChildItem -Path Env: -Recurse -Include ARM_*,AZURE_*,TF_*,SYSTEM_* | Sort-Object -Property Name | Format-Table | Write-Host -ForegroundColor Yellow 
}

# Configure az cli for devops
az extension add --name azure-devops 
az devops configure --defaults organization="$OrganizationUrl"

# Get identifiers using az devops cli
Write-Debug "Agent pool is '$AgentPoolName'"
# Find agent pool
$agentPoolId = $(az pipelines pool list --query="[?name=='$AgentPoolName'].id | [0]")
Write-Debug "Agent pool id is '$agentPoolId'"
$agentId = $(az pipelines agent list --agent-name $AgentName --pool-id $agentPoolId --query="[0].id")
Write-Debug "Agent id is '$agentId'"
if ($DebugPreference -ine "SilentlyContinue") {
    Write-Debug "Pool information:"
    az pipelines pool list --query="[?name=='$AgentPoolName'].id"
    # Show agent details
    Write-Debug "Agent information:"
    az pipelines agent list --agent-name $agentName --pool-id $agentPoolId | Write-Host -ForegroundColor Yellow 
}

# az devops cli does not (yet) allow updates, so using the REST API
$apiUrl = "$OrganizationUrl/_apis/distributedtask/pools/$agentPoolId/agents/$agentId"
Write-Debug "REST API Url: $apiUrl"

# Prepare REST request
$requestHeaders = @{
    Authorization = "Bearer $Token"
}
$requestBody = @{
    enabled = $Enabled.ToString().ToLowerInvariant()
}

Invoke-WebRequest -Uri $apiUrl -Headers $requestHeaders -Body $requestBody -Method Patch
#Invoke-WebRequest -Uri $apiUrl -Body $requestBody -Method Patch -Token $PAT

# Get agent status
$enabledStatus = $(az pipelines agent list --agent-name $AgentName --pool-id $agentPoolId --query="[0].enabled")
Write-Information "Agent $AgentName enabled status is '$enabledStatus'"


Write-Host "##vso[task.setvariable variable=agentEnabled;isOutput=true]$enabledStatus"