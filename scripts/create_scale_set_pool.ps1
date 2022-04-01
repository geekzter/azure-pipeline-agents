#!/usr/bin/env pwsh

#Requires -Version 7

param ( 
    [parameter(Mandatory=$false)][string]$OrganizationUrl=$env:AZDO_ORG_SERVICE_URL ?? $env:SYSTEM_COLLECTIONURI,
    [parameter(Mandatory=$true)][string][validateset("Linux", "Windows")]$OS,
    [parameter(Mandatory=$false)][string]$PoolName,
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE ?? "default",
    [parameter(Mandatory=$false)][string]$Token=$env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN ?? $env:SYSTEM_ACCESSTOKEN
) 
$apiVersion="7.1-preview.1"
if (!$Token) {
    Write-Warning "No access token found. Please specify -Token or set the AZURE_DEVOPS_EXT_PAT or AZDO_PERSONAL_ACCESS_TOKEN environment variable."
    exit
}

function Create-RequestHeaders(
    [parameter(Mandatory=$true)][string]$OrganizationUrl
)
{
    $base64AuthInfo = [Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes(":${Token}"))
    $authHeader = "Basic $base64AuthInfo"
    Write-Debug "Authorization: $authHeader"
    $requestHeaders = @{
        Accept = "application/json"
        Authorization = $authHeader
        "Content-Type" = "application/json"
    }

    return $requestHeaders
}

function Get-Pool(
    [parameter(Mandatory=$true)][string]$OrganizationUrl,
    [parameter(Mandatory=$true)][int[]]$PoolId
)
{
    $poolIdString = ($PoolId -join ",")
    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/pools?poolIds=${poolIdString}&api-version=${apiVersion}"
    Write-Debug "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -OrganizationUrl $OrganizationUrl
    Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Get | Set-Variable pools

    if (($DebugPreference -ine "SilentlyContinue") -and $pools.value) {
        $pools.value | Write-Debug
    }
    return $pools
}

function List-ScaleSetPools(
    [parameter(Mandatory=$true)][string]$OrganizationUrl
)
{
    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/elasticpools?api-version=${apiVersion}"
    Write-Debug "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -OrganizationUrl $OrganizationUrl
    # Invoke-WebRequest -Uri $apiUrl -Headers $requestHeaders -Method Get
    Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Get | Set-Variable scaleSets
    
    if (($DebugPreference -ine "SilentlyContinue") -and $scaleSets.value) {
        $scaleSets.value | Write-Debug
    }
    return $scaleSets
}

function Create-ScaleSetPool(
    [parameter(Mandatory=$true)][string]$OrganizationUrl,
    [parameter(Mandatory=$true)][string]$OS,
    [parameter(Mandatory=$false)][string]$PoolName,
    [parameter(Mandatory=$false)][bool]$AuthorizeAllPipelines=$true,
    [parameter(Mandatory=$false)][bool]$AutoProvisionProjectPools=$true,
    [parameter(Mandatory=$false)][int]$ProjectId
)
{
    # Retrieve Terraform generated configuration
    $jsonPath = Join-Path (Split-Path $PSScriptRoot -Parent) data $Workspace "${OS}_elastic_pool.json"
    if (!(Test-Path $jsonPath)) {
        Write-Warning "${jsonPath} not found, has infrastrucure been provisioned in workspace '${Workspace}'?"
        exit
    }
    # Get-Content $jsonPath | Set-Variable requestJson
    # $requestJson | ConvertFrom-Json | Set-Variable scaleSetTemplate

    #### Test
    Get-Content ./tmpew.json | Set-Variable requestJson
    Write-Debug "Request JSON: $requestJson"
    $requestJson | ConvertFrom-Json | Set-Variable scaleSetTemplate
    $scaleSetTemplate | Out-String | Write-Debug
    $scaleSetTemplate.azureId = "/subscriptions/84c1a2c7-585a-4753-ad28-97f69618cf12/resourceGroups/pipeline-test-agents-xtxc/providers/Microsoft.Compute/virtualMachineScaleSets/pipeline-test-agents-xtxc-linux-agents"
    $scaleSetTemplate.osType = "linux"
    $scaleSetTemplate | ConvertTo-Json | Set-Variable requestJson
    Write-Debug "Request JSON: $requestJson"
    #####

    $OrganizationUrl = $OrganizationUrl -replace "/$","" # Strip trailing '/'
    $scaleSetTemplate.azureId.Split('/')[-1] | Write-Host
    if ([string]::IsNullOrEmpty($PoolName)) {
        $PoolName = $scaleSetTemplate.azureId.Split('/')[-1]
    }
    Write-Debug "PoolName: $PoolName"
    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/elasticpools?poolName=${PoolName}&authorizeAllPipelines=${AuthorizeAllPipelines}&autoProvisionProjectPools=${AutoProvisionProjectPools}&projectId=${ProjectId}&api-version=${apiVersion}"
    Write-Debug "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -OrganizationUrl $OrganizationUrl

    Write-Debug "Request JSON: $requestJson"
    $requestJson | Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Post | Set-Variable createdScaleSet

    if (($DebugPreference -ine "SilentlyContinue") -and $createdScaleSet.value) {
        $createdScaleSet.value | Write-Debug
    }
    $createdScaleSet
}

# Main
$OrganizationUrl = $OrganizationUrl -replace "/$","" # Strip trailing '/'
Write-Debug "OrganizationUrl: '$OrganizationUrl'"

# Test whether pool already exists
List-ScaleSetPools -OrganizationUrl $OrganizationUrl | Set-Variable existingScaleSets
$existingScaleSets.value | ForEach-Object {
    $_.poolId
} | Set-Variable existingPoolIds
Write-Debug "poolIds: $existingPoolIds"

Get-Pool -OrganizationUrl $OrganizationUrl -PoolId $existingPoolIds | Set-Variable pools
$pools.value | ForEach-Object {
    $_.name
} | Set-Variable existingPoolNames
if ($existingPoolNames -and ($existingPoolNames -contains $PoolName)) {
    Write-Warning "Pool '$PoolName' already exists"
    exit
}

Create-ScaleSetPool -OrganizationUrl $OrganizationUrl -OS $OS.ToLowerInvariant() -PoolName $PoolName | Set-Variable scaleSet
if ($scaleSet) {
    $scaleSet.value
}