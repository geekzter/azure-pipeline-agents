#!/usr/bin/env pwsh

#Requires -Version 7

param ( 
    [parameter(Mandatory=$false)][string]$OrganizationUrl=$env:AZDO_ORG_SERVICE_URL,
    [parameter(Mandatory=$false,ParameterSetName='ServiceConnection')][string]$ServiceConnectionName,
    [parameter(Mandatory=$false,ParameterSetName='ServiceConnection')][string]$ServiceConnectionProjectName,
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE ?? "default",
    [parameter(Mandatory=$false)][string]$Token=$env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN
) 

$jsonDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) data $Workspace
Get-ChildItem $jsonDirectory -Filter *_elastic_pool.json | Set-Variable jsonFiles
if (!$jsonFiles) {
    "No elastic pool definitions found in {0}" -f $jsonDirectory | Write-Warning
    exit 0
}

$jsonFiles | ForEach-Object {
    $os = $_.Name.Split("_")[0]
    . (Join-Path $PSScriptRoot create_scale_set_pool.ps1) -OrganizationUrl $OrganizationUrl `
                                                          -ServiceConnectionName $ServiceConnectionName `
                                                          -ServiceConnectionProjectName $ServiceConnectionProjectName `
                                                          -Workspace $Workspace `
                                                          -Token $Token `
                                                          -OS $os
}