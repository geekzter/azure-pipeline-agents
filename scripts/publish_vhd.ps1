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
    ./publish_vhd.ps1 -VHDUrl "https://packer12345.blob.core.windows.net/system/Microsoft.Compute/Images/images/packer-osDisk.00000000-0000-0000-0000-000000000000.vhd?se=2022-02-07&sp=racwdl&sv=2018-11-09&sr=c&skoid=00000000-0000-0000-0000-000000000000&sktid=00000000-0000-0000-0000-000000000000&skt=2022-01-31T10%3A39%3A58Z&ske=2022-02-07T00%3A00%3A00Z&sks=b&skv=2018-11-09&sig=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX3D" `
                      -GalleryResourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Shared" 
                      -GalleryName OurGallery -ImageDefinitionName Ubuntu2004 -Publisher PrivatePipelineImages -Offer Ubuntu -SKU 20 -OsType linux
#> 
#Requires -Version 7

### Arguments
param ( 

    [parameter(Mandatory=$true)][string]$GalleryResourceGroupId,
    [parameter(Mandatory=$false)][string]$GalleryName,
    [parameter(Mandatory=$false)][string]$VHDUrl=$env:IMAGE_VHD_URL,
    [parameter(Mandatory=$false)][string]$ImageDefinitionName,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][hashtable]$ImageDefinitionVersionTags,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$Publisher,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$Offer,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$SKU,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$OsType,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string[]]$TargetRegion
) 
Write-Verbose $MyInvocation.line 

$galleryResourceGroupName = $GalleryResourceGroupId.Split("/")[-1]
$gallerySubscriptionId = $GalleryResourceGroupId.Split("/")[2]
if ($VHDUrl -match "^https://(?<account>[\w]+)\.") {
    $storageAccountName = $matches["account"]
} else {
    Write-Warning "`nCould not parse storage account name from VHD url, exiting"
    exit
}
$tags=@("application=Pipeline Agents","provisioner=azure-cli")

# Image Gallery
if (!$galleryResourceGroupName -or !$GalleryName) {
    Write-Warning "`nShared Image Gallery not specified, exiting"
    exit
}

az group list --subscription $gallerySubscriptionId --query "[?name=='$galleryResourceGroupName']" -o json | ConvertFrom-Json | Set-Variable galleryResourceGroup
if (!$galleryResourceGroup) {
    Write-Warning "`nShared Gallery Resource Group '$galleryResourceGroupName' does not exist, exiting"
    exit
}
az sig list --resource-group $galleryResourceGroupName --subscription $gallerySubscriptionId --query "[?name=='$GalleryName']" -o json | ConvertFrom-Json | Set-Variable gallery
if (!$gallery) {
    Write-Host "`nShared Gallery '$GalleryName' does not exist yet, creating it..."
    az sig create --gallery-name $GalleryName --resource-group $galleryResourceGroupName -l $galleryResourceGroup.location --subscription $gallerySubscriptionId --tags $tags
}

if (!$ImageDefinitionName) {
    Write-Warning "`nImage Definition not specified, exiting"
    exit
}
az sig image-definition list --gallery-name $GalleryName `
                             --resource-group $galleryResourceGroupName `
                             --subscription $gallerySubscriptionId `
                             --query "[?name=='$ImageDefinitionName']" `
                             -o json | ConvertFrom-Json | Set-Variable imageDefinition
if (!$imageDefinition) {
    if (!$Publisher -or !$Offer -or !$SKU -or !$OsType) {
        Write-Warning "`nImage Definition '$ImageDefinitionName' does not exist yet and arguments to create it were not (all) not specified, exiting"
        exit
    }
    Write-Host "`nImage Definition '$ImageDefinitionName' (${Publisher}/${Offer}/${SKU}) does not exist yet, creating it..."
    az sig image-definition create --gallery-image-definition $ImageDefinitionName `
                                   --gallery-name $GalleryName `
                                   --resource-group $galleryResourceGroupName `
                                   --subscription $gallerySubscriptionId `
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
                          --resource-group $galleryResourceGroupName `
                          --subscription $gallerySubscriptionId `
                          --query "[?tags.versionlabel=='$imageDefinitionVersionLabel']" | ConvertFrom-Json | Set-Variable imageVersion

if ($imageVersion) {
    Write-Warning "`nImage Definition '$ImageDefinitionName' with tag versionlabel='$imageDefinitionVersionLabel' already exists"
} else {
    az sig image-version list --gallery-image-definition $ImageDefinitionName `
                              --gallery-name $GalleryName `
                              --resource-group $galleryResourceGroupName --query "[].name" -o json `
                              --subscription $gallerySubscriptionId `
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
                                --resource-group $galleryResourceGroupName `
                                --subscription $gallerySubscriptionId `
                                --target-regions ($TargetRegion ?? $galleryResourceGroup.location) `
                                --os-vhd-uri $VHDUrl `
                                --os-vhd-storage-account $storageAccountName `
                                --tags $imageTags | ConvertFrom-Json | Set-Variable imageVersion
}

$imageVersion | Format-List