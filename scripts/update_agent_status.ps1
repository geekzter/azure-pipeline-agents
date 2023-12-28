#!/usr/bin/env pwsh
<#
    Requires 
    - 'Project Collection Build Service (org)' to be added to Agent Pool ACL
    - 'Limit job authorization scope to current project for non-release pipelines' disabled

#>
param ( 
    [parameter(Mandatory=$true)][string]$AgentNamePrefix,
    [parameter(Mandatory=$true)][string]$AgentPoolName,
    [parameter(Mandatory=$false)][switch]$Enabled,
    [parameter(Mandatory=$false)][string]$OrganizationUrl=($env:AZDO_ORG_SERVICE_URL ?? $env:SYSTEM_COLLECTIONURI)
) 
Write-Verbose $MyInvocation.line 
. (Join-Path $PSScriptRoot functions.ps1)

function UpdateAgent(
    [parameter(Mandatory=$true)][int]$AgentId,
    [parameter(Mandatory=$true)][int]$AgentPoolId,
    [parameter(Mandatory=$true)][hashtable]$Settings,
    [parameter(Mandatory=$false)][string]$Token=($env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN ?? $env:SYSTEM_ACCESSTOKEN)
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
    Write-Verbose "`$requestBody: $requestBody"
    if ($DebugPreference -ine "SilentlyContinue") {
        Invoke-WebRequest -Uri $apiUrl -Headers $requestHeaders -Body $requestBody -Method Get | Write-Host -ForegroundColor Yellow 
    }
    $updateResponse = Invoke-WebRequest -Uri $apiUrl -Headers $requestHeaders -Body $requestBody -Method Patch
    Write-Verbose "Response status: $($updateResponse.StatusDescription)"
    Write-Debug $updateResponse | Out-String
    $updateResponseContent = $updateResponse.Content | ConvertFrom-Json
    Write-Debug $updateResponseContent | Out-String

    return $updateResponseContent
}

Write-Information "VerbosePreference: $VerbosePreference"
Write-Verbose "DebugPreference: $DebugPreference"
Write-Debug "AgentNamePrefix: '$AgentNamePrefix'"
Write-Debug "AgentPoolName: '$AgentPoolName'"
Write-Debug "Enabled: '$Enabled'"
Write-Debug "OrganizationUrl: '$OrganizationUrl'"

# List environment variables (debug)
if ($DebugPreference -ine "SilentlyContinue") {
    Get-ChildItem -Path Env: -Recurse -Include ARM_*,AZURE_*,TF_*,SYSTEM_* | Sort-Object -Property Name | Out-String | Write-Host -ForegroundColor Yellow 
}

Login-AzDO -OrganizationUrl $OrganizationUrl

# Get identifiers using az devops cli
$agentPoolId = $(az pipelines pool list --query="[?name=='$AgentPoolName'].id | [0]")
if (!$agentPoolId) {
    Write-Error "Could not retrieve ID of Agent Pool '${AgentPoolName}' in organization '${OrganizationUrl}'"
    exit
}
Write-Debug "Agent pool id is '$agentPoolId'"
$agentIds = $(az pipelines agent list --pool-id $agentPoolId --query="[?starts_with(name,'$AgentNamePrefix')].id" | ConvertFrom-Json)
Write-Debug "Agent ids: $agentIds"
if ($DebugPreference -ine "SilentlyContinue") {
    Write-Debug "Pool information:"
    az pipelines pool list --query="[?name=='$AgentPoolName']" | Write-Host -ForegroundColor Yellow 
}

foreach ($agentId in $agentIds) {
    Write-Information "Processing agent with id '$agentId'..."
    # Get agent status prior to update
    $agent = az pipelines agent show --agent-id $agentId --pool-id $agentPoolId | ConvertFrom-Json
    if ($DebugPreference -ine "SilentlyContinue") {
        Write-Debug "Agent information (raw):"
        az pipelines agent show --agent-id $agentId --pool-id $agentPoolId | Write-Host -ForegroundColor Yellow 
        Write-Debug "Agent information:`n$($agent | Out-String)"
    }
    
    $initialEnabledStatus = $($agent.enabled)
    Write-Host "Agent $($agent.name) ($agentId) enabled status before update is '$initialEnabledStatus'"

    # Check whether current and desired status is different, otherwise skip update
    if ([System.Convert]::ToBoolean($initialEnabledStatus) -ne $Enabled) {
        # az devops cli does not (yet) allow agent updates, so use the REST API
        $settings = @{
            enabled = $Enabled.ToString().ToLowerInvariant()
        }
        $null = UpdateAgent -AgentId $agentId -AgentPoolId $agentPoolId -Settings $settings

        # Get agent status
        $enabledStatus = $(az pipelines agent show --agent-id $agentId --pool-id $agentPoolId --query="enabled")
    } else {
        $enabledStatus = $initialEnabledStatus
    }
    Write-Host "Agent $($agent.name) ($agentId) enabled status after update is '$enabledStatus'"
}
