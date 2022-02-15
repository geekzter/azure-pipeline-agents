#!/usr/bin/env pwsh
#Requires -Version 7.2

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

# Set additional environment variables as Codespace secrets
# https://docs.github.com/en/codespaces/managing-your-codespaces/managing-encrypted-secrets-for-your-codespaces

Set-Location $repoDirectory/scripts
Write-Host "To prevent losing (or to reconnect to) a terminal session, type $($PSStyle.Bold)ct <terraform workspace>$($PSStyle.Reset)"
Write-Host "To update Codespace configuration, run $($PSStyle.Bold)$repoDirectory/.devcontainer/createorupdate.ps1$($PSStyle.Reset)"
Write-Host "To provision infrastructure, run $($PSStyle.Bold)$repoDirectory/scripts/deploy.ps1 -Apply$($PSStyle.Reset)"
Write-Host "To destroy infrastructure, run $($PSStyle.Bold)$repoDirectory/scripts/deploy.ps1 -Destroy$($PSStyle.Reset)"
