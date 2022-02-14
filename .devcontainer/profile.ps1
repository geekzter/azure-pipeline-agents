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

Set-Location $repoDirectory/scripts
Write-Host "To update Codespace configuration, run $repoDirectory/.devcontainer/createorupdate.ps1"
Write-Host "To provision infrastructure, run $repoDirectory/scripts/deploy.ps1 -Apply"
Write-Host "To destroy infrastructure, run $repoDirectory/scripts/deploy.ps1 -Destroy"
