#!/usr/bin/env pwsh

#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE
) 

$application = "Pipeline Agents"

$imageBuildResourceGroupNmme = $(az group list --query "[?contains(name,'images-build') && tags.application=='$application' && tags.workspace=='$Workspace'].name" -o tsv)

if (!$imageBuildResourceGroupNmme) {
    Write-Warning "No image build resource group found for workspace '$Workspace', exiting"
    exit
}

$resourceIds = $(az resource list -g $imageBuildResourceGroupNmme --query "[].id" -o tsv)
if (!$resourceIds) {
    Write-Warning "No resources found in resource group '$imageBuildResourceGroupNmme', exiting"
    exit
}

Write-Host "Deleting resources from resource group '$imageBuildResourceGroupNmme'..."
az resource delete --ids $resourceIds --query "[].name" -o tsv
Write-Host "Deleted resources from resource group '$imageBuildResourceGroupNmme'..."
