#!/usr/bin/env pwsh

<# 
.SYNOPSIS 
    Finds VHD in given Resource Group and publishes it in a Shared Image Gallery
 
.DESCRIPTION 
    The image build script (https://github.com/actions/virtual-environments/blob/main/helpers/GenerateResourcesAndImage.ps1)
    creates a storage account, storage container and VHD. 
    This scipt finds the VHD based on the Resource Group name that is input to aforementioned script. 
    The VHD found will be published, creating required artifacts including the Shared Image Gallery itself if it does not exist yet.

.EXAMPLE
    ./publish_vhd.ps1 packer-99999 -GalleryResourceGroupName Shared -GalleryName testgal -ImageDefinitionName UbuntuPipelineHost -Publisher PrivatePipelineImages -Offer Ubuntu -SKU 18 -OsType linux
#> 
#Requires -Version 7

### Arguments
param ( 
    # [parameter(Mandatory=$true)][string]$PackerResourceGroupId,
    [parameter(Mandatory=$true)][string]$PackerResourceGroupName,
    # [parameter(Mandatory=$false)][string]$GalleryResourceGroupId,
    [parameter(Mandatory=$false)][string]$GalleryResourceGroupName,
    [parameter(Mandatory=$false)][string]$GalleryName,
    [parameter(Mandatory=$false)][string]$ImageDefinitionName,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][hashtable]$ImageDefinitionVersionTags,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$Publisher,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$Offer,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$SKU,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$OsType,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string[]]$TargetRegion
) 
Write-Verbose $MyInvocation.line 

az group list --query "[?name=='$PackerResourceGroupName']" | ConvertFrom-Json | Set-Variable packerResourceGroup
if (!$packerResourceGroup) {
    Write-Warning "`nResource group '$PackerResourceGroupName' does not exist, exiting"
    exit
}

# Find VHD in Packer Resource Group
az storage account list -g $PackerResourceGroupName --query "[0]" -o json | ConvertFrom-Json | Set-Variable storageAccount
$vhdPath = $(az storage blob directory list -c system -d "Microsoft.Compute/Images/images" --account-name $($storageAccount.name) --query "[?ends_with(@.name, 'vhd')].name" -o tsv)
if (!$vhdPath) {
    Write-Warning "`nCould not find VHD in storage account ${storageAccount}, exiting"
    exit
}
$vhdUrl = "$($storageAccount.primaryEndpoints.blob)system/${vhdPath}"
Write-Host "`nVHD: $vhdUrl"

# Image Gallery
if (!$GalleryResourceGroupName -or !$GalleryName) {
    Write-Warning "`nShared Image Gallery not specified, exiting"
    exit
}

az group list --query "[?name=='$GalleryResourceGroupName']" -o json | ConvertFrom-Json | Set-Variable galleryResourceGroup
$tags=@("application=Pipeline Agents","provisioner=azure-cli")
if (!$galleryResourceGroup) {
    Write-Host "`nShared Gallery Resource Group '$GalleryResourceGroupName' does not exist yet, creating it..."
    az group create -n $GalleryResourceGroupName -l $storageAccount.primaryLocation --tags $tags -o json | ConvertFrom-Json | Set-Variable galleryResourceGroup
}
az sig list --resource-group $GalleryResourceGroupName --query "[?name=='$GalleryName']" -o json | ConvertFrom-Json | Set-Variable gallery
if (!$gallery) {
    Write-Host "`nShared Gallery '$GalleryName' does not exist yet, creating it..."
    az sig create --gallery-name $GalleryName --resource-group $GalleryResourceGroupName -l $galleryResourceGroup.location --tags $tags
}

if (!$ImageDefinitionName) {
    Write-Warning "`nImage Definition not specified, exiting"
    exit
}
az sig image-definition list --gallery-name $GalleryName --resource-group $GalleryResourceGroupName --query "[?name=='$ImageDefinitionName']" -o json | ConvertFrom-Json | Set-Variable imageDefinition
if (!$imageDefinition) {
    if (!$Publisher -or !$Offer -or !$SKU -or !$OsType) {
        Write-Warning "`nImage Definition '$ImageDefinitionName' does not exist yet and arguments to create it were not (all) not specified, exiting"
        exit
    }
    Write-Host "`nImage Definition '$ImageDefinitionName' (${Publisher}/${Offer}/${SKU}) does not exist yet, creating it..."
    az sig image-definition create --gallery-image-definition $ImageDefinitionName `
                                   --gallery-name $GalleryName `
                                   --resource-group $GalleryResourceGroupName `
                                   --publisher $Publisher --offer $Offer --sku $SKU `
                                   --os-type $OsType --os-state Generalized `
                                   --tags $tags | ConvertFrom-Json | Set-Variable imageDefinition
}

if (!$ImageDefinitionVersionTags -or !$ImageDefinitionVersionTags.ContainsKey("versionlabel")) {
    Write-Warning "`nImageDefinitionVersionTags not specified, exiting"
    exit
}
$imageDefinitionVersionLabel = $ImageDefinitionVersionTags["versionlabel"]
az sig image-version list --gallery-image-definition $ImageDefinitionName `
                          --gallery-name $GalleryName `
                          --resource-group $GalleryResourceGroupName `
                          --query "[?tags.versionlabel=='$imageDefinitionVersionLabel']" | ConvertFrom-Json | Set-Variable imageVersion

if ($imageVersion) {
    Write-Warning "`nImage Definition '$ImageDefinitionName' with tag versionlabel='$imageDefinitionVersionLabel' already exists"
} else {
    az sig image-version list --gallery-image-definition $ImageDefinitionName `
                              --gallery-name $GalleryName `
                              --resource-group $GalleryResourceGroupName --query "[].name" -o json `
                              | ConvertFrom-Json `
                              | ForEach-Object {[version]$_} `
                              | Sort-Object -Descending | Select-Object -First 1 `
                              | Set-Variable latestVersion
    # Increment version
    [version]$newVersion = New-Object version $latestVersion.Major, $latestVersion.Minor, ($latestVersion.Build+1)
    $newVersionString = $newVersion.ToString()

    [System.Collections.ArrayList]$imageTags = $tags.Clone()
    foreach ($tagName in $ImageDefinitionVersionTags.Keys) {
        $tagValue = $ImageDefinitionVersionTags[$tagName]
        $imageTags.Add("${tagName}=${tagValue}") | Out-Null
    }
    Write-Host "`nTags that will be applied to version ${newVersionString} of Image Definition '$ImageDefinitionName':"
    $imageTags.GetEnumerator() | Sort-Object -Property Name | Format-Table

    Write-Host "`nCreating Image version ${newVersionString} for Image Definition '$ImageDefinitionName'..."
    az sig image-version create --gallery-image-definition $ImageDefinitionName `
                                --gallery-name $GalleryName `
                                --gallery-image-version $newVersionString `
                                --resource-group $GalleryResourceGroupName `
                                --target-regions ($TargetRegion ?? $storageAccount.primaryLocation) `
                                --os-vhd-uri $vhdUrl `
                                --os-vhd-storage-account $($storageAccount.name) `
                                --tags $imageTags | ConvertFrom-Json | Set-Variable imageVersion
}

$imageVersion | Format-List