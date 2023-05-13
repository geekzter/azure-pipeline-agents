#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Create scale set agent pool
 
.DESCRIPTION 
    Terraform generates a template (<os>_elastic_pool.json) in data/<WORKSPACE> for each Virtual Machine Scale Set is creates.
    This script takes those templates and creates a scale set agent pool.

.EXAMPLE
    ./create_scale_set_pool.ps1 -OS linux -ServiceConnectionName my-azure-subscription -ServiceConnectionProjectName PipelineAgents
#> 
#Requires -Version 7

param ( 
    [parameter(Mandatory=$false)][string]$OrganizationUrl=$env:AZDO_ORG_SERVICE_URL,
    [parameter(Mandatory=$true)][string][validateset("Linux", "Windows")]$OS,
    [parameter(Mandatory=$false)][string]$PoolName,
    [parameter(Mandatory=$false,ParameterSetName='ServiceConnection')][string]$ServiceConnectionName,
    [parameter(Mandatory=$false,ParameterSetName='ServiceConnection')][string]$ServiceConnectionProjectName,
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE ?? "default",
    [parameter(Mandatory=$false)][string]$Token=$env:AZURE_DEVOPS_EXT_PAT
) 

### Internal Functions
. (Join-Path $PSScriptRoot functions.ps1)

# Validation & Parameter processing
if (!$OrganizationUrl) {
    Write-Warning "OrganizationUrl is required. Please specify -OrganizationUrl or set the AZDO_ORG_SERVICE_URL environment variable."
    exit 1
}
$OrganizationUrl = $OrganizationUrl -replace "/$","" # Strip trailing '/'
if (!$Workspace) {
    Write-Warning "Workspace is required. Please specify -OrganizationUrl or set the TF_WORKSPACE environment variable."
    exit 1
}

# Retrieve service connection GUID's
if ($ServiceConnectionName -and $ServiceConnectionProjectName) {
    Login-AzDO -OrganizationUrl $OrganizationUrl
    az devops service-endpoint list --org $OrganizationUrl `
                                    --project $ServiceConnectionProjectName `
                                    --query "[?name=='$ServiceConnectionName']" `
                                    | ConvertFrom-Json | Set-Variable endpoint
    if (!$endpoint) {
        Write-Warning "Service Connection '$ServiceConnectionName' not found in project '$ServiceConnectionProjectName'"
        exit 1
    }
    Write-Debug $endpoint
    $serviceEndpointId = $endpoint.id
    $serviceEndpointScope = $endpoint.serviceEndpointProjectReferences[0].projectReference.id
}

# Main
"`nDeploying {0} scale set pool ({1})..." -f $OS, $Workspace | Write-Host
Write-Debug "OrganizationUrl: '$OrganizationUrl'"

# Retrieve Terraform generated configuration
$jsonFile = Join-Path (Split-Path $PSScriptRoot -Parent) data $Workspace "${OS}_elastic_pool.json"
Write-Debug "JSON Path: $jsonFile"
if (!(Test-Path $jsonFile)) {
    Write-Warning "${jsonPath} not found, has infrastructure been provisioned in workspace '${Workspace}'?"
    exit 1
}
Get-Content $jsonFile | Set-Variable requestJson
$requestJson | ConvertFrom-Json | Set-Variable scaleSetTemplate
Write-Debug "Request JSON: $requestJson"
# Validation and optional manipulation of template
if ([string]::IsNullOrEmpty($scaleSetTemplate.azureId)) {
    Write-Warning "azureId is required, but missing in '$jsonFile"
    exit 1
}
if ($serviceEndpointId) {
    $scaleSetTemplate.serviceEndpointId = $serviceEndpointId
}
if ([string]::IsNullOrEmpty($scaleSetTemplate.serviceEndpointId)) {
    Write-Warning "serviceEndpointId is required, but missing in '$jsonFile"
    exit 1
}
if ($serviceEndpointScope) {
    $scaleSetTemplate.serviceEndpointScope = $serviceEndpointScope
}
if ([string]::IsNullOrEmpty($scaleSetTemplate.serviceEndpointScope)) {
    Write-Warning "serviceEndpointScope is required, but missing in '$jsonFile"
    exit 1
}
$scaleSetTemplate | Out-String | Write-Debug
$scaleSetTemplate | ConvertTo-Json | Set-Variable requestJson
Write-Debug "Request JSON: $requestJson"

"VMSS: {0}" -f $scaleSetTemplate.azureId.Split('/')[-1] | Write-Debug
if ([string]::IsNullOrEmpty($PoolName)) {
    if ($Workspace -ieq "default") {
        "{0}{1} scale set agents" -f $OS.Substring(0,1).ToUpperInvariant(), $OS.Substring(1) | Set-Variable PoolName
    } else {
        # "{0} ({1})" -f $PoolName, $Workspace | Set-Variable PoolName # Makes sense once we can remove elastic pools via REST API
        $PoolName = $scaleSetTemplate.azureId.Split('/')[-1]
    }
    Write-Debug "PoolName: $PoolName"
}

# Test whether pool already exists
Get-ScaleSetPools -OrganizationUrl $OrganizationUrl -Token $Token | Set-Variable existingScaleSets
$existingScaleSets.value | ForEach-Object {
    $_.poolId
} | Set-Variable existingPoolIds
Write-Debug "poolIds: $existingPoolIds"

if ($existingPoolIds) {
    Get-Pool -OrganizationUrl $OrganizationUrl -PoolId $existingPoolIds -Token $Token | Set-Variable pools
    $pools.value | ForEach-Object {
        $_.name
    } | Set-Variable existingPoolNames
    if ($existingPoolNames -and ($existingPoolNames -contains $PoolName)) {
        Write-Warning "Pool '$PoolName' already exists at ${OrganizationUrl}/_settings/agentpools"
        exit 0
    }    
}

# Create VMSS pool
New-ScaleSetPool -OrganizationUrl $OrganizationUrl `
                 -OS $OS.ToLowerInvariant() `
                 -PoolName $PoolName `
                 -RequestJson $RequestJson `
                 -Token $Token `
                 | Set-Variable scaleSet

if ($scaleSet.elasticPool) {
    $scaleSet.elasticPool | Format-List
}