#!/usr/bin/env pwsh
<#
    Deletes an Azure Pipelines agent pool
#>
param ( 
    [parameter(Mandatory=$false)][string]$AgentPoolName,
    [parameter(Mandatory=$false)][string]$OrganizationUrl=($env:AZDO_ORG_SERVICE_URL ?? $env:SYSTEM_COLLECTIONURI)
) 
Write-Verbose $MyInvocation.line 
. (Join-Path $PSScriptRoot functions.ps1)
$OrganizationUrl = $OrganizationUrl.Trim('/')
$apiVersion="7.1"

if (!($AgentPoolName)) {
    Write-Warning "AgentPoolName is empty"
    exit
}

Login-AzDO -OrganizationUrl $OrganizationUrl

# GET https://dev.azure.com/{organization}/_apis/distributedtask/pools?poolName={poolName}&properties={properties}&poolType={poolType}&actionFilter={actionFilter}&api-version=7.1

$requestHeaders = @{
    Accept = "application/json"
    Authorization = "Bearer $authHeader ${env:AZURE_DEVOPS_EXT_PAT}"
    "Content-Type" = "application/json"
}
$restPoolName = [Uri]::EscapeUriString($AgentPoolName)
$requestUrl = "${OrganizationUrl}/_apis/distributedtask/pools?poolName=${restPoolName}&api-version=${apiVersion}"
Write-Verbose "REST API Url: $requestUrl"
Invoke-WebRequest -Uri $requestUrl `
                  -Method Get `
                  -Headers $requestHeaders `
                  | ConvertFrom-Json `
                  | Set-Variable pools

if ($pools.count -eq 0) {
    Write-Warning "No pools found with name ${AgentPoolName}"
    exit
} else {
    $pool = $pools.value[0]
    $poolId = $pool.id
    $poolName = $pool.name
}
Write-Host "Deleting pool ${poolName} with id ${poolId}..."
$requestUrl = "${OrganizationUrl}/_apis/distributedtask/pools/${poolId}?api-version=${apiVersion}"
Write-Verbose "REST API Url: $requestUrl"
Invoke-WebRequest -Uri $requestUrl `
                  -Method Delete `
                  -Headers $requestHeaders `
                  | ConvertFrom-Json `
                  | Set-Variable pools