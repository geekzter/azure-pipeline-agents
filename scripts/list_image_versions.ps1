#!/usr/bin/env pwsh

<# 
.EXAMPLE
    ./list_image_versions.ps1 -GalleryResourceGroupName Shared -GalleryName testgal -ImageDefinitionName Ubuntu2204
#> 
#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$false)][string]$GalleryResourceGroupName=$env:PIPELINE_DEMO_COMPUTE_GALLERY_RESOURCE_GROUP_NAME,
    [parameter(Mandatory=$false)][string]$GalleryName=$env:PIPELINE_DEMO_COMPUTE_GALLERY_NAME,
    [parameter(Mandatory=$false)][string]$ImageDefinitionName
) 

function List-ImageVersions (
    [parameter(Mandatory=$true)][string]$GalleryResourceGroupName,
    [parameter(Mandatory=$true)][string]$GalleryName,
    [parameter(Mandatory=$true)][string]$ImageDefinitionName
) {
    Write-Host "az sig image-version list --gallery-image-definition $ImageDefinitionName --gallery-name $GalleryName --resource-group $GalleryResourceGroupName"
    az sig image-version list --gallery-image-definition $ImageDefinitionName `
                              --gallery-name $GalleryName `
                              --resource-group $GalleryResourceGroupName `
                              --query "[].{Name:'$ImageDefinitionName', Version:name, Build:tags.build, Label:tags.versionlabel, Commit:tags.commit, Date:publishingProfile.publishedDate, Regions:publishingProfile.targetRegions[*].name, Status:provisioningState}" `
                              -o json | ConvertFrom-Json `
                              | Sort-Object -Property Date -Descending

}

if (!$GalleryName) {
    if ($GalleryResourceGroupName) {
        Write-Host "No Gallery name specified, finding first gallery in Resource Group '$GalleryResourceGroupName'"
        az sig list --resource-group $GalleryResourceGroupName --query "[0].name" -o tsv | Set-Variable GalleryName
    } else {
        Write-Host "No Gallery name specified, finding first gallery in subscription"
        az sig list --query "[0]" `
                    -o json | ConvertFrom-Json | Set-Variable gallery
        Write-Debug $gallery
        if ($gallery) {
            $GalleryName = $gallery.name
            $GalleryResourceGroupName = $gallery.resourceGroup
        }
    }
}
if (!$GalleryName) {
    Write-Warning "Could bot find Shared Image Gallery with the specified parameters"
    exit
}


Write-Host "Retrieving image versions from Shared Image Gallery '$GalleryName'..." -NoNewline
if ($ImageDefinitionName) {
    List-ImageVersions -GalleryResourceGroupName $GalleryResourceGroupName `
                       -GalleryName $GalleryName `
                       -ImageDefinitionName $ImageDefinitionName | Set-Variable imageVersions
} else {
    az sig image-definition list --gallery-name $GalleryName `
                                 --resource-group $GalleryResourceGroupName `
                                 --query "[].name" `
                                 -o tsv | Set-Variable imageDefinitionNames
                                 
    [System.Collections.ArrayList]$imageVersions = @()
    foreach ($imageDefinitionName in $imageDefinitionNames) {
        List-ImageVersions -GalleryResourceGroupName $GalleryResourceGroupName `
                           -GalleryName $GalleryName `
                           -ImageDefinitionName $ImageDefinitionName | Set-Variable specificImageVersions
        foreach ($specificImageVersion in $specificImageVersions) {
            $imageVersions.Add($specificImageVersion) | Out-Null
        }
        Write-Host "." -NoNewline
    }
}
$imageVersions | Sort-Object -Property Date -Descending | Format-Table -Property Name, Version, Build, Label, Date, Status, Commit, Regions