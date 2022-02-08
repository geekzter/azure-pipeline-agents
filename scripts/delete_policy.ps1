#!/usr/bin/env pwsh


#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE,
    [parameter(Mandatory=$false)][string]$Suffix
) 

$policyNamePrefix = "no-vm-extension-policy"
if ($Workspace) {
    $policyNamePrefix += "-${Workspace}"
}
if ($Suffix) {
    $policyNamePrefix += "-${Suffix}"
}

az policy definition list --query "[?starts_with(name,'$policyNamePrefix')]" -o json | ConvertFrom-Json | Set-Variable policies
foreach ($policy in $policies) {
    az policy definition delete --name $policy.name
}