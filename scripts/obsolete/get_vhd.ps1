#!/usr/bin/env pwsh

<# 
.SYNOPSIS 
    Finds VHD in given Resource Group
 
.DESCRIPTION 
    The image build script (https://github.com/actions/runner-images/blob/main/helpers/GenerateResourcesAndImage.ps1)
    creates a storage account, storage container and VHD. 
    This scipt finds the VHD based on the Resource Group name that is created by aforementioned script.

.EXAMPLE
    ./publish_vhd.ps1 -PackerResourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Packer"
#> 
#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$true)][string]$PackerResourceGroupId=$env:PIPELINE_DEMO_PACKER_BUILD_RESOURCE_GROUP_ID,
    [parameter(Mandatory=$false)][string]$BlobPrefix,
    [parameter(Mandatory=$false)][switch]$GenerateSAS,
    [parameter(Mandatory=$false)][string]$VHDUrlEnvironmentVariableName="IMAGE_VHD_URL"
) 
Write-Verbose $MyInvocation.line 

$packerResourceGroupName = $PackerResourceGroupId.Split("/")[-1]
$packerSubscriptionId = $PackerResourceGroupId.Split("/")[2]
$storageContainerName = "system"

az group list --subscription $packerSubscriptionId --query "[?name=='$packerResourceGroupName']" | ConvertFrom-Json | Set-Variable packerResourceGroup
if (!$packerResourceGroup) {
    Write-Host "az group list --subscription $packerSubscriptionId --query `"[?name=='$packerResourceGroupName']`""
    Write-Error "`nResource group '$packerResourceGroupName' does not exist in subscription '$packerSubscriptionId', exiting"
    exit
}

# Find VHD in Packer Resource Group
az storage account list -g $packerResourceGroupName --subscription $packerSubscriptionId --query "[0]" -o json | ConvertFrom-Json | Set-Variable storageAccount
if (!$storageAccount) {
    Write-Host "az storage account list -g $packerResourceGroupName --subscription $packerSubscriptionId --query `"[0]`" -o json"
    Write-Error "`nResource group '$packerResourceGroupName' in subscription '$packerSubscriptionId' does not contain a storage account, do you have data plane access? Exiting"
    exit
}
$storageAccountName = $storageAccount.name
$jmesQuery = "?ends_with(@.name, 'vhd')"
if ($BlobPrefix) {
    $jmesQuery += "&&contains(@.name, '$BlobPrefix')"
}
$jmesPath = "[${jmesQuery}]"
Write-Debug "az storage blob directory list -c $storageContainerName -d `"Microsoft.Compute/Images/images`" --account-name $storageAccountName --subscription $packerSubscriptionId --query `"${jmesPath}`""
az storage blob directory list -c $storageContainerName -d "Microsoft.Compute/Images/images" --account-name $storageAccountName --subscription $packerSubscriptionId --query "${jmesPath}" | ConvertFrom-Json | Set-Variable vhdBlob
$vhdBlob | Format-List | Out-String | Write-Debug
$vhdBlob.metadata | Format-List | Out-String | Write-Debug
$vhdBlob.properties | Format-List | Out-String | Write-Debug
if (!$vhdBlob) {
    Write-Error "`nCould not find VHD in storage account ${storageAccountName}, exiting"
    exit
}
$vhdPath = $vhdBlob.name
if ($BlobPrefix -and !$vhdPath.Contains($BlobPrefix)) {
    # Double check
    Write-Error "`n${vhdPath} does not contain $BlobPrefix. Wrong blob, exiting"
    exit
}
$vhdUrl = "$($storageAccount.primaryEndpoints.blob)${storageContainerName}/${vhdPath}"
$vhdUrlResult = $vhdUrl
if ($GenerateSAS) {
    # $sasToken=$(az storage blob generate-sas -c $storageContainerName -n $vhdPath --account-name $storageAccountName --permissions r --expiry (Get-Date).AddDays(7).ToString("yyyy-MM-dd") --subscription $packerSubscriptionId -o tsv)
    az storage blob generate-sas -c $storageContainerName `
                                 -n $vhdPath `
                                 --account-name $storageAccountName `
                                 --account-key $(az storage account keys list -n $storageAccountName -g $packerResourceGroupName --subscription $packerSubscriptionId --query "[0].value" -o tsv) `
                                 --permissions acdrw `
                                 --expiry (Get-Date).AddDays(7).ToString("yyyy-MM-dd") `
                                 --start "$([DateTime]::UtcNow.AddDays(-30).ToString('s'))Z" `
                                 --subscription $packerSubscriptionId `
                                 --full-uri `
                                 -o tsv | Set-Variable vhdUrlResult
}

Write-Host "`nVHD: $vhdUrlResult"
if ($VHDUrlEnvironmentVariableName) {
    Set-Item env:${VHDUrlEnvironmentVariableName} $vhdUrlResult
}

