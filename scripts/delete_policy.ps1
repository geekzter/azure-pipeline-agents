#!/usr/bin/env pwsh


#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$false)][string]$Workspace
) 

$policyNamePrefix = "no-vm-extension-policy"
if ($Workspace) {
    $policyNamePrefix += "-${Workspace}"
}

az policy definition list --query "[?starts_with(name,'$policyNamePrefix')]" -o json | ConvertFrom-Json | Set-Variable policies
foreach ($policy in $policies) {
    az policy definition delete --name $policy.name
}