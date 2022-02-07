#!/usr/bin/env pwsh

<# 
.SYNOPSIS 
    Finds VHD in given Resource Group
 
.DESCRIPTION 
    The image build script (https://github.com/actions/virtual-environments/blob/main/helpers/GenerateResourcesAndImage.ps1)
    creates a storage account, storage container and VHD. 
    This scipt finds the VHD based on the Resource Group name that is created by aforementioned script.

.EXAMPLE
    ./publish_vhd.ps1 -PackerResourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Packer"
#> 
#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$true)][string]$PackerResourceGroupId,
    [parameter(Mandatory=$false)][switch]$GenerateSAS,
    [parameter(Mandatory=$false)][string]$VHDUrlEnvironmentVariableName="IMAGE_VHD_URL"
) 
Write-Verbose $MyInvocation.line 

$packerResourceGroupName = $PackerResourceGroupId.Split("/")[-1]
$packerSubscriptionId = $PackerResourceGroupId.Split("/")[2]
$storageContainerName = "system"

Write-Debug "az group list --subscription $packerSubscriptionId --query `"[?name=='$packerResourceGroupName']`""
az group list --subscription $packerSubscriptionId --query "[?name=='$packerResourceGroupName']" | ConvertFrom-Json | Set-Variable packerResourceGroup
if (!$packerResourceGroup) {
    Write-Warning "`nResource group '$packerResourceGroupName' does not exist in subscription '$packerSubscriptionId', exiting"
    exit
}

# Find VHD in Packer Resource Group
Write-Debug "az storage account list -g $packerResourceGroupName --subscription $packerSubscriptionId --query `"[0]`" -o json"
az storage account list -g $packerResourceGroupName --subscription $packerSubscriptionId --query "[0]" -o json | ConvertFrom-Json | Set-Variable storageAccount
if (!$storageAccount) {
    Write-Warning "`nResource group '$packerResourceGroupName' in subscription '$packerSubscriptionId' does not contain a storage account, do you have data plane access? Exiting"
    exit
}
$storageAccountName = $storageAccount.name
$vhdPath = $(az storage blob directory list -c $storageContainerName -d "Microsoft.Compute/Images/images" --account-name $storageAccountName --subscription $packerSubscriptionId --query "[?ends_with(@.name, 'vhd')].name" -o tsv)
if (!$vhdPath) {
    Write-Warning "`nCould not find VHD in storage account ${storageAccountName}, exiting"
    exit
}

$vhdUrl = "$($storageAccount.primaryEndpoints.blob)${storageContainerName}/${vhdPath}"
$vhdUrlResult = $vhdUrl
if ($GenerateSAS) {
    Write-Host "az storage blob generate-sas -c $storageContainerName -n $vhdPath --as-user --auth-mode login --account-name $storageAccountName --permissions r --expiry (Get-Date).AddDays(7).ToString(`"yyyy-MM-dd`") --subscription $packerSubscriptionId -o tsv"
    $sasToken=$(az storage blob generate-sas -c $storageContainerName -n $vhdPath --as-user --auth-mode login --account-name $storageAccountName --permissions r --expiry (Get-Date).AddDays(7).ToString("yyyy-MM-dd") --subscription $packerSubscriptionId -o tsv)
    $vhdUrlResult = "${vhdUrl}?${sasToken}"
}

Write-Host "`nVHD: $vhdUrlResult"
if ($VHDUrlEnvironmentVariableName) {
    Set-Item env:${VHDUrlEnvironmentVariableName} $vhdUrlResult
}

