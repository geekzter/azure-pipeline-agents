#!/usr/bin/env pwsh
<#
    Requires 'Project Collection Build Service (org)' to be added to Agent Pool ACL
#>
param ( 
    [parameter(Mandatory=$true)][string]$AgentName,
    [parameter(Mandatory=$true)][string]$AgentPoolName,
    [parameter(Mandatory=$false)][switch]$Enabled,
    [parameter(Mandatory=$false)][string]$OrganizationUrl=$env:SYSTEM_COLLECTIONURI,
    [parameter(Mandatory=$false)][string]$Token=$env:SYSTEM_ACCESSTOKEN
) 

function UpdateAgent(
    [parameter(Mandatory=$true)][int]$AgentId,
    [parameter(Mandatory=$true)][int]$AgentPoolId,
    [parameter(Mandatory=$true)][hashtable]$Settings
)
{
    # az devops cli does not (yet) allow updates, so using the REST API
    $OrganizationUrl = $OrganizationUrl -replace "/$","" # Strip trailing '/'
    $apiVersion="5.1"
    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/pools/${AgentPoolId}/agents/${AgentId}?api-version=${apiVersion}"
    Write-Debug "REST API Url: $apiUrl"

    # Prepare REST request
    $base64AuthInfo = [Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes(":${Token}"))
    $authHeader = "Basic $base64AuthInfo"
    Write-Debug "Authorization: $authHeader"
    $requestHeaders = @{
        Accept = "application/json"
        Authorization = $authHeader
        "Content-Type" = "application/json"
    }
    $Settings["id"] = $AgentId
    $requestBody = $Settings | ConvertTo-Json
    if ($DebugPreference -ine "SilentlyContinue") {
        Invoke-WebRequest -Uri $apiUrl -Headers $requestHeaders -Body $requestBody -Method Get | Write-Host -ForegroundColor Yellow 
    }
    #Invoke-WebRequest -Uri $apiUrl -Headers $requestHeaders -Body $requestBody -Method Patch
    $updateResponse = Invoke-WebRequest -Uri $apiUrl -Headers $requestHeaders -Body $requestBody -Method Patch
    Write-Information "Response status: $($updateResponse.StatusDescription)"
    Write-Debug $updateResponse | Out-String
    $updateResponseContent = $updateResponse.Content | ConvertFrom-Json
    Write-Debug $updateResponseContent | Out-String

    return $updateResponseContent
}

Write-Host "DebugPreference: $DebugPreference"
Write-Debug "AgentName: '$AgentName'"
Write-Debug "AgentPoolName: '$AgentPoolName'"
Write-Debug "Enabled: '$Enabled'"
Write-Debug "OrganizationUrl: '$OrganizationUrl'"
Write-Debug "Token: '$Token'"


# List environment variables (debug)
if ($DebugPreference -ine "SilentlyContinue") {
    Get-ChildItem -Path Env: -Recurse -Include ARM_*,AZURE_*,TF_*,SYSTEM_* | Sort-Object -Property Name | Out-String | Write-Host -ForegroundColor Yellow 
}

# Configure az cli for devops
az extension add --name azure-devops 
az devops configure --defaults organization="$OrganizationUrl"

# Get identifiers using az devops cli
# Find agent pool
$agentPoolId = $(az pipelines pool list --query="[?name=='$AgentPoolName'].id | [0]")
Write-Debug "Agent pool id is '$agentPoolId'"
$agentId = $(az pipelines agent list --agent-name $AgentName --pool-id $agentPoolId --query="[0].id")
Write-Debug "Agent id is '$agentId'"
if ($DebugPreference -ine "SilentlyContinue") {
    Write-Debug "Pool information:"
    az pipelines pool list --query="[?name=='$AgentPoolName']" | Write-Host -ForegroundColor Yellow 
    Write-Debug "Agent information:"
    az pipelines agent list --agent-name $agentName --pool-id $agentPoolId | Write-Host -ForegroundColor Yellow 
}

# Get agent status prior to update
$initialEnabledStatus = $(az pipelines agent list --agent-name $AgentName --pool-id $agentPoolId --query="[0].enabled")
Write-Information "Agent $AgentName enabled status before update is '$initialEnabledStatus'"

# Check whether current and desired status is different, otherwise skip update
if ([System.Convert]::ToBoolean($initialEnabledStatus) -ne $Enabled) {
    # az devops cli does not (yet) allow agent updates, so use the REST API
    $settings = @{
        enabled = $Enabled.ToString().ToLowerInvariant()
    }
    $null = UpdateAgent -AgentId $agentId -AgentPoolId $agentPoolId -Settings $settings

    # Get agent status
    $enabledStatus = $(az pipelines agent list --agent-name $AgentName --pool-id $agentPoolId --query="[0].enabled")
} else {
    Write-Debug "Skipping update"
    $enabledStatus = $initialEnabledStatus
}
Write-Information "Agent $AgentName enabled status after update is '$enabledStatus'"

Write-Host "##vso[task.setvariable variable=agentInitiallyEnabled;isOutput=true]$initialEnabledStatus"
Write-Host "##vso[task.setvariable variable=agentEnabled;isOutput=true]$enabledStatus"
