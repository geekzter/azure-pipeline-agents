#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$true)][string]$SubnetId,
    [parameter(Mandatory=$true)][string]$NsgId,
    [parameter(Mandatory=$false)][int]$MaxTries=10,
    [parameter(Mandatory=$false)][int]$WaitSeconds=10
) 

Set-PSDebug -Trace 2

Write-Debug "NsgId: $NsgId"
Write-Debug "SubnetId: $SubnetId"
az network vnet subnet show --ids ${SubnetId} --query networkSecurityGroup.id -o tsv | Set-Variable existingNsgId
Write-Debug "existingNsgId: $existingNsgId"

$tries = 0
while (($NsgId -ine $existingNsgId) -and ($tries -le $MaxTries)) {
    Start-Sleep -Seconds $WaitSeconds
    $tries++
    az network vnet subnet update --ids ${SubnetId} --nsg ${NsgId} --query networkSecurityGroup.id
    az network vnet subnet update --ids ${SubnetId} --nsg ${NsgId} --query networkSecurityGroup.id -o tsv 2>&1 | Set-Variable existingNsgId
    Write-Debug "existingNsgId (${tries}): ${existingNsgId}"
    az resource wait --updated --ids ${SubnetId}
}

if ($tries -gt $MaxTries) {
    Write-Error "Failed to update subnet security group after $MaxTries tries"
    exit 1
}