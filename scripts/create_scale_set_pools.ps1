#!/usr/bin/env pwsh

#Requires -Version 7

param ( 
    [parameter(Mandatory=$false)][string]$OrganizationUrl=$env:AZDO_ORG_SERVICE_URL ?? $env:SYSTEM_COLLECTIONURI,
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE ?? "default",
    [parameter(Mandatory=$false)][string]$Token=$env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN ?? $env:SYSTEM_ACCESSTOKEN
) 

$jsonDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) data $Workspace
Get-ChildItem $jsonDirectory -Filter *_elastic_pool.json | ForEach-Object {
    $os = $_.Name.Split("_")[0]
    . (Join-Path $PSScriptRoot create_scale_set_pool.ps1) -OrganizationUrl $OrganizationUrl -Workspace $Workspace -Token $Token -OS $os
}