#!/usr/bin/env pwsh

#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE,
    [parameter(Mandatory=$false)][string]$Suffix
) 

$jmesQuery = "starts_with(name,'pipeline-build-')"
if ($Workspace) {
    $jmesQuery += " && contains(name,'-${Workspace}-')"
}
if ($Suffix) {
    $jmesQuery += " && ends_with(name,'-${Suffix}')"
}

$jmesPath = "[?${jmesQuery}]"

az policy set-definition list --query "${jmesPath}" -o json | ConvertFrom-Json | Set-Variable policySets
foreach ($policySet in $policySets) {
    Write-Host "Deleting policy set '$($policySet.name)'..."
    az policy set-definition delete --name $policySet.name
}

az policy definition list --query "${jmesPath}" -o json | ConvertFrom-Json | Set-Variable policies
foreach ($policy in $policies) {
    Write-Host "Deleting policy '$($policy.name)'..."
    az policy definition delete --name $policy.name
}