#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Create scale set agent pools
 
.DESCRIPTION 
    Terraform generates a template (<os>_elastic_pool.json) in data/<WORKSPACE> for each Virtual Machine Scale Set is creates.
    This script takes those templates and creates a scale set agent pool for each.

.EXAMPLE
    ./create_scale_set_pools.ps1 -ServiceConnectionName my-azure-subscription -ServiceConnectionProjectName PipelineAgents
#> 
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