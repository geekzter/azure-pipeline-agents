#!/usr/bin/env pwsh

#Requires -Version 7

Write-Host "Finding Shareg Image Galleries in subscription '$(az account show --query "name" -o tsv)..."
az sig list -o json | ConvertFrom-Json | Set-Variable galleries
foreach ($gallery in $galleries) {
    Write-Host "Finding image definitions in gallery '$($gallery.name)'..."
    az sig image-definition list --gallery-name $gallery.name `
                                 --resource-group $gallery.resourceGroup `
                                 -o json | ConvertFrom-Json | Set-Variable imageDefinitions
    foreach ($imageDefinition in $imageDefinitions) {
        Write-Host "Finding failed versions of image definition '$($imageDefinition.name)'..."
        az sig image-version list --gallery-image-definition $imageDefinition.name `
                                  --gallery-name $gallery.name `
                                  --resource-group $imageDefinition.resourceGroup `
                                  --query "[?provisioningState=='Failed']" `
                                  -o json | ConvertFrom-Json | Set-Variable failedImageVersions
        foreach ($failedImageVersion in $failedImageVersions) {
            Write-Host "Deleting failed version '$($failedImageVersion.name)'..."
            az sig image-version delete --gallery-image-definition $imageDefinition.name `
                                        --gallery-image-version $failedImageVersion.name `
                                        --gallery-name $gallery.name `
                                        --resource-group $failedImageVersion.resourceGroup
        }
    }
}