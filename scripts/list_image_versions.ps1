#!/usr/bin/env pwsh

<# 
.EXAMPLE
    ./list_image_versions.ps1 -GalleryResourceGroupName Shared -GalleryName testgal -ImageDefinitionName UbuntuPipelineHost 
#> 
#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$true)][string]$GalleryResourceGroupName,
    [parameter(Mandatory=$true)][string]$GalleryName,
    [parameter(Mandatory=$true)][string]$ImageDefinitionName
) 

az sig image-version list --gallery-image-definition $ImageDefinitionName `
                          --gallery-name $GalleryName `
                          --resource-group $GalleryResourceGroupName `
                          --query "[].{Version:name, Build:tags.build, Label:tags.versionlabel, Date:publishingProfile.publishedDate}" `
                          -o table
