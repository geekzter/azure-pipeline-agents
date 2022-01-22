#!/usr/bin/env pwsh

<# 
.SYNOPSIS 
    Finds VHD in given Resource Group and publishes it in Shared Image Gallery
 
.DESCRIPTION 
    The image build script (https://github.com/actions/virtual-environments/blob/main/helpers/GenerateResourcesAndImage.ps1)
    creates a storage account, storage container and VHD. This scipt finfs the VHD based on the Resource Group name that is input to aforementioned script.

.EXAMPLE
    ./publish_vhd.ps1 packer-99999 -GalleryResourceGroupName Shared -GalleryName testgal -ImageDefinitionName UbuntuPipelineHost -Publisher PrivatePipelineImages -Offer Ubuntu -SKU 18 -OsType linux
#> 
#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$true)][string]$PackerResourceGroupName,
    [parameter(Mandatory=$false)][string]$GalleryResourceGroupName,
    [parameter(Mandatory=$false)][string]$GalleryName,
    [parameter(Mandatory=$false)][string]$ImageDefinitionName,
    [parameter(Mandatory=$false,HelpMessage="Only required if Gallery Image Definition does not exist yet")][string]$ImageDefinitionVersionLabel,
    [parameter(Mandatory=$false,HelpMessage="Only required if Gallery Image Definition does not exist yet")][string]$ImageDefinitionBuild,
    [parameter(Mandatory=$false,HelpMessage="Only required if Gallery Image Definition does not exist yet")][string]$Publisher,
    [parameter(Mandatory=$false,HelpMessage="Only required if Gallery Image Definition does not exist yet")][string]$Offer,
    [parameter(Mandatory=$false,HelpMessage="Only required if Gallery Image Definition does not exist yet")][string]$SKU,
    [parameter(Mandatory=$false,HelpMessage="Only required if Gallery Image Definition does not exist yet")][string]$OsType
) 
Write-Host $MyInvocation.line 

az group list --query "[?name=='$PackerResourceGroupName']" | ConvertFrom-Json | Set-Variable packerResourceGroup
if (!$packerResourceGroup) {
    Write-Warning "Resource group $packerResourceGroup does not exist, exiting"
    exit
}

# Find VHD in Packer Resource Group
az storage account list -g $PackerResourceGroupName --query "[0]" -o json | ConvertFrom-Json | Set-Variable storageAccount
$storageAccountKey =  $(az storage account keys list -n $storageAccount.name --query "[0].value" -o tsv)
$vhdPath = $(az storage blob directory list -c system -d "Microsoft.Compute/Images/images" --account-name $storageAccount.name --account-key $storageAccountKey --query "[?ends_with(name,'vhd')].name" -o tsv)
$vhdUrl = "$($storageAccount.primaryEndpoints.blob)system/${vhdPath}"
Write-Host "`nVHD: $vhdUrl"

# Image Gallery
if (!$GalleryResourceGroupName -or !$GalleryName) {
    Write-Warning "Shared Image Gallery not specified, exiting"
    exit
}

az group list --query "[?name=='$GalleryResourceGroupName']" -o json | ConvertFrom-Json | Set-Variable galleryResourceGroup
$tags=@("application=Pipeline Agents","provisioner=azure-cli")
if (!$galleryResourceGroup) {
    Write-Host "Shared Gallery Resource Group '$GalleryResourceGroupName' does not exist yet, creating it..."
    az group create -n $GalleryResourceGroupName -l $storageAccount.primaryLocation --tags $tags -o json | ConvertFrom-Json | Set-Variable galleryResourceGroup
}
az sig list --resource-group $GalleryResourceGroupName --query "[?name=='$GalleryName']" -o json | ConvertFrom-Json | Set-Variable gallery
if (!$gallery) {
    Write-Host "Shared Gallery '$GalleryName' does not exist yet, creating it..."
    az sig create --gallery-name $GalleryName --resource-group $GalleryResourceGroupName -l $galleryResourceGroup.location --tags $tags
}

if (!$ImageDefinitionName) {
    Write-Warning "Image Definition not specified, exiting"
    exit
}
az sig image-definition list --gallery-name $GalleryName --resource-group $GalleryResourceGroupName --query "[?name=='$ImageDefinitionName']" -o json | ConvertFrom-Json | Set-Variable imageDefinition
if (!$imageDefinition) {
    if (!$Publisher -or !$Offer -or !$SKU -or !$OsType -or !$ImageDefinitionVersionLabel) {
        Write-Warning "Image Definition '$ImageDefinitionName' does not exist yet and arguments to create it were not (all) not specified, exiting"
        exit
    }
    Write-Host "Image Definition '$imageDefinition' does not exist yet, creating it..."
    az sig image-definition create --gallery-image-definition $ImageDefinitionName `
                                   --gallery-name $GalleryName `
                                   --resource-group $GalleryResourceGroupName `
                                   --publisher $Publisher --offer $Offer --sku $SKU `
                                   --os-type $OsType --os-state Generalized `
                                   --tags $tags | ConvertFrom-Json | Set-Variable imageDefinition
}


az sig image-version list --gallery-image-definition $ImageDefinitionName `
                          --gallery-name $GalleryName `
                          --resource-group $GalleryResourceGroupName `
                          --query "[?tags.versionlabel=='$ImageDefinitionVersionLabel']" | ConvertFrom-Json | Set-Variable imageVersion

if ($imageVersion) {
    Write-Warning "Image Definition '$ImageDefinitionName' with tag versionlabel='$ImageDefinitionVersionLabel' already exists"
} else {
    [version]$latestVersion = $(az sig image-version list --gallery-image-definition $ImageDefinitionName `
                                                          --gallery-name $GalleryName `
                                                          --resource-group $GalleryResourceGroupName --query "max_by([],&name).name" -o tsv)
    # Increment version
    [version]$newVersion = New-Object version $latestVersion.Major, $latestVersion.Minor, ($latestVersion.Build+1)
    $newVersionString = $newVersion.ToString()

    Write-Host "Creating Image version ${newVersionString}..."
    [System.Collections.ArrayList]$imageTags = $tags.Clone()
    $imageTags.Add("build=${ImageDefinitionBuild}") | Out-Null
    $imageTags.Add("versionlabel=${ImageDefinitionVersionLabel}") | Out-Null
    az sig image-version create --gallery-image-definition $ImageDefinitionName `
                                --gallery-name $GalleryName `
                                --gallery-image-version $newVersionString `
                                --resource-group $GalleryResourceGroupName `
                                --os-vhd-uri $vhdUrl `
                                --os-vhd-storage-account $storageAccount.name `
                                --tags $imageTags | ConvertFrom-Json | Set-Variable imageVersion
}

$imageVersion | Format-List