#!/usr/bin/env pwsh

#Requires -Version 7

param ( 
    [parameter(Mandatory=$false)][string]$OrganizationUrl=$env:AZDO_ORG_SERVICE_URL ?? $env:SYSTEM_COLLECTIONURI,
    [parameter(Mandatory=$false)][int]$Top=50
) 

### Internal Functions
. (Join-Path $PSScriptRoot functions.ps1)

# Validation

function Get-ScaleSetPoolLogs(
    [parameter(Mandatory=$true)][string]$OrganizationUrl,

    [parameter(Mandatory=$true)][int]$PoolId,

    [parameter(Mandatory=$false)][int]$Top=50,

    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token=$env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN ?? $env:SYSTEM_ACCESSTOKEN

)
{
    Write-Debug "PoolId: $PoolId"
    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/elasticpools/${PoolId}/logs?$top=${Top}&api-version=${apiVersion}"
    Write-Verbose "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -Token $Token
    Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Get | Set-Variable scaleSetLog

    if (($DebugPreference -ine "SilentlyContinue") -and $scaleSetLog.value) {
        $scaleSetLog.value | Write-Debug
    }
    $scaleSetLog
}

# Main
$OrganizationUrl = $OrganizationUrl -replace "/$","" # Strip trailing '/'
Write-Debug "OrganizationUrl: '$OrganizationUrl'"

Login-AzDO -OrganizationUrl $OrganizationUrl

# Retrieve pools
Get-ScaleSetPools -OrganizationUrl $OrganizationUrl | Set-Variable existingScaleSets
$existingScaleSets.value | ForEach-Object {
    $_.poolId
} | Set-Variable existingPoolIds
Write-Debug "poolIds: $existingPoolIds"

if (!$existingPoolIds) {
    Write-Warning "No scale set pools found."
    exit
}

Get-Pool -OrganizationUrl $OrganizationUrl -PoolId $existingPoolIds| Set-Variable pools

$logItems = [System.Collections.ArrayList]@()
foreach ($pool in $pools.value) {
    "Retrieving logs for pool {1} '{0}'" -f $pool.name, $pool.id | Write-Verbose
    Get-ScaleSetPoolLogs -OrganizationUrl $OrganizationUrl -PoolId $pool.id -Top $Top | Set-Variable logs
    $logs.value | ForEach-Object {
        $_.timestamp = (Get-Date $_.timestamp -Format "yyyy-MM-dd HH:mm:ss")
        $_ | Add-Member -NotePropertyName poolName -NotePropertyValue $pool.name
        $logItems.Add($_) | Out-Null
    } 
}

$logItems | Sort-Object -Property timestamp, id -Descending | Format-Table -Property timestamp,id,poolName,poolId,level,operation,message