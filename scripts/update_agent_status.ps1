#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$false)][switch]$Enabled,
    [parameter(Mandatory=$false)][string]$AgentName,
    [parameter(Mandatory=$false)][string]$AgentPoolName,
    [parameter(Mandatory=$false)][string]$Organization,
    #[parameter(Mandatory=$false)][string]$Project,
    [parameter(Mandatory=$false)][string]$Token=$env:AZURE_DEVOPS_EXT_PAT
) 



# List environment variables (debug)
if ($DebugPreference -ine "SilentlyContinue") {
    Get-ChildItem -Path Env:AZURE_* | Sort-Object -Property Name | Write-Host -ForegroundColor Yellow 
}


# Configure az cli for devops
az extension add --name azure-devops 
az devops configure --defaults organization="https://dev.azure.com/$Organization" #project="$Project"

# Get identifiers using az devops cli
Write-Debug "Agent pool is '$AgentPoolName'"
# Find agent pool
$agentPoolId = $(az pipelines pool list --query="[?name=='$AgentPoolName'].id | [0]")
Write-Debug "Agent pool id is '$agentPoolId'"
$agentId = $(az pipelines agent list --agent-name $AgentName --pool-id $agentPoolId --query="[0].id")
Write-Debug "Agent id is '$agentId'"
if ($DebugPreference -ine "SilentlyContinue") {
    # Show agent details
    Write-Debug "Agent information:"
    az pipelines agent list --agent-name $agentName --pool-id $agentPoolId | Write-Host -ForegroundColor Yellow 
}

# az devops cli does not (yet) allow updates, so using the REST API
$apiUrl = "https://dev.azure.com/$Organization/_apis/distributedtask/pools/$agentPoolId/agents/$agentId"
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