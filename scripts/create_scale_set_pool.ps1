#!/usr/bin/env pwsh

#Requires -Version 7

param ( 
    [parameter(Mandatory=$false)][string]$OrganizationUrl=$env:AZDO_ORG_SERVICE_URL ?? $env:SYSTEM_COLLECTIONURI,
    [parameter(Mandatory=$true)][string][validateset("Linux", "Windows")]$OS,
    [parameter(Mandatory=$false)][string]$PoolName,
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE ?? "default",
    [parameter(Mandatory=$false)][string]$Token=$env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN ?? $env:SYSTEM_ACCESSTOKEN
) 

### Internal Functions
. (Join-Path $PSScriptRoot functions.ps1)

# Validation
if ([string]::IsNullOrEmpty($PoolName)) {
    "{0}{1} scale set agents" -f $OS.Substring(0,1).ToUpperInvariant(), $OS.Substring(1) | Set-Variable PoolName
    if ($Workspace -and ($Workspace -ne "default")) {
        "{0} ({1})" -f $PoolName, $Workspace | Set-Variable PoolName
    }
    Write-Debug "PoolName: $PoolName"
}
if (!$Token) {
    Write-Warning "No access token found. Please specify -Token or set the AZURE_DEVOPS_EXT_PAT or AZDO_PERSONAL_ACCESS_TOKEN environment variable."
    exit
}

function Create-ScaleSetPool(
    [parameter(Mandatory=$true)][string]$OrganizationUrl,
    [parameter(Mandatory=$true)][string]$OS,
    [parameter(Mandatory=$false)][string]$PoolName,
    [parameter(Mandatory=$false)][string]$RequestJson,
    [parameter(Mandatory=$false)][bool]$AuthorizeAllPipelines=$true,
    [parameter(Mandatory=$false)][bool]$AutoProvisionProjectPools=$true,
    [parameter(Mandatory=$false)][int]$ProjectId
)
{
    "Creating scale set pool '$PoolName'..." | Write-Host
    Write-Debug "PoolName: $PoolName"
    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/elasticpools?poolName=${PoolName}&authorizeAllPipelines=${AuthorizeAllPipelines}&autoProvisionProjectPools=${AutoProvisionProjectPools}&projectId=${ProjectId}&api-version=${apiVersion}"
    Write-Verbose "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -Token $Token

    Write-Debug "Request JSON: $RequestJson"
    $RequestJson | Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Post | Set-Variable createdScaleSet

    "Created scale set pool '$PoolName'" | Write-Host

    if (($DebugPreference -ine "SilentlyContinue") -and $createdScaleSet.elasticPool) {
        $createdScaleSet.elasticPool | Write-Debug
    }
    return $createdScaleSet
}

# Main
$OrganizationUrl = $OrganizationUrl -replace "/$","" # Strip trailing '/'
Write-Debug "OrganizationUrl: '$OrganizationUrl'"

# Retrieve Terraform generated configuration
$jsonFile = Join-Path (Split-Path $PSScriptRoot -Parent) data $Workspace "${OS}_elastic_pool.json"
Write-Debug "JSON Path: $jsonFile"
if (!(Test-Path $jsonFile)) {
    Write-Warning "${jsonPath} not found, has infrastructure been provisioned in workspace '${Workspace}'?"
}
Get-Content $jsonFile | Set-Variable requestJson
$requestJson | ConvertFrom-Json | Set-Variable scaleSetTemplate
Write-Debug "Request JSON: $requestJson"
# Validation and optional manipulation of template
if ([string]::IsNullOrEmpty($scaleSetTemplate.serviceEndpointId)) {
    throw "serviceEndpointId is required, but missing in '$jsonFile"
}
if ([string]::IsNullOrEmpty($scaleSetTemplate.serviceEndpointScope)) {
    throw "serviceEndpointScope is required, but missing in '$jsonFile"
}
$scaleSetTemplate | Out-String | Write-Debug
$scaleSetTemplate | ConvertTo-Json | Set-Variable requestJson
Write-Debug "Request JSON: $requestJson"

"VMSS: {0}" -f $scaleSetTemplate.azureId.Split('/')[-1] | Write-Debug
if ([string]::IsNullOrEmpty($PoolName)) {
    $PoolName = $scaleSetTemplate.azureId.Split('/')[-1]
}

# Test whether pool already exists
List-ScaleSetPools -OrganizationUrl $OrganizationUrl -Token $Token | Set-Variable existingScaleSets
$existingScaleSets.value | ForEach-Object {
    $_.poolId
} | Set-Variable existingPoolIds
Write-Debug "poolIds: $existingPoolIds"

if ($existingPoolIds) {
    Get-Pool -OrganizationUrl $OrganizationUrl -PoolId $existingPoolIds | Set-Variable pools
    $pools.value | ForEach-Object {
        $_.name
    } | Set-Variable existingPoolNames
    if ($existingPoolNames -and ($existingPoolNames -contains $PoolName)) {
        Write-Warning "Pool '$PoolName' already exists at ${OrganizationUrl}/_settings/agentpools"
        exit
    }    
}

# Create VMSS pool
Create-ScaleSetPool -OrganizationUrl $OrganizationUrl `
                    -OS $OS.ToLowerInvariant() `
                    -PoolName $PoolName `
                    -RequestJson $RequestJson `
                    | Set-Variable scaleSet

if ($scaleSet.elasticPool) {
    $scaleSet.elasticPool | Format-List
}