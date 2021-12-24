#!/usr/bin/env pwsh

param ( 
    [parameter(Mandatory=$true)][string]$VmName,
    [parameter(Mandatory=$true)][string]$ResourceGroupName,
    [parameter(Mandatory=$true)][string]$Publisher,
    [parameter(Mandatory=$true)][string]$ExtensionType,
    [parameter(Mandatory=$false)][string]$SkipExtensionName   
) 

$condition = "publisher=='${Publisher}' && typePropertiesType=='${ExtensionType}'"
if ($SkipExtensionName) {
    $condition += " && name!='${SkipExtensionName}'"    
}

$extensionID = $(az vm extension list -g $ResourceGroupName --vm-name $VmName --query "[?${condition}].id" -o tsv)

if ($extensionID) {
    Write-Host "Removing extension with type '${Publisher}.${ExtensionType}' from VM ${VmName}..."
    az vm extension delete --ids $extensionID
} else {
    Write-Information "Extension with type '${Publisher}.${ExtensionType}' not found on VM ${VmName}" -InformationAction Continue
}