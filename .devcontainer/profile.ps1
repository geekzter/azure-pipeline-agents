#!/usr/bin/env pwsh

$repoDirectory = (Split-Path (Split-Path (Get-Item $MyInvocation.MyCommand.Path).Target -Parent) -Parent)
$scriptDirectory = (Join-Path $repoDirectory "scripts")

# Manage PATH environment variable
[System.Collections.ArrayList]$pathList = $env:PATH.Split(":")
# Insert script path into PATH, so scripts can be called from anywhere
if (!$pathList.Contains($scriptDirectory)) {
    $pathList.Insert(1,$scriptDirectory)
}
$env:PATH = $pathList -Join ":"

# Making sure pwsh is the default shell for Terraform local-exec
$env:SHELL = (Get-Command pwsh).Source

Set-Location $repoDirectory
Write-Host "To update Codespace configuration, run $repoDirectory/.devcontainer/createorupdate.ps1"
Write-Host "To provision infrastructure, make sure you're logged in with Azure CLI e.g. run 'az login' and 'az account set --subscription 00000000-0000-0000-0000-000000000000'. Then change to the $repoDirectory/terraform directory and run 'terraform apply'"
Write-Host "To destroy infrastructure, replace 'apply' with 'destroy' in above statement(s)"