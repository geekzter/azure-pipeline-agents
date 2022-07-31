#!/usr/bin/env pwsh
<# 
.EXAMPLE
    ./get_ssh_key_pair.ps1 -KeyName ~/.ssh/id_rsa_dev
.EXAMPLE
    ./get_ssh_key_pair.ps1 -InformationAction Continue
#> 
param ( 
    [parameter(Mandatory=$false,HelpMessage="Key prefix to write key pait to (~/.ssh/id_rsa[.pub])")][string]$Keyname,
    [parameter(Mandatory=$false)][switch]$Force=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)

# Get configuration
$terraformDirectory = (Join-Path (Split-Path -parent -Path $PSScriptRoot) "terraform")
Push-Location $terraformDirectory
$resourceGroup = (Get-TerraformOutput resource_group_name)
$sshPrivateKeyID = (Get-TerraformOutput ssh_private_key_id)
$sshPublicKeyID = (Get-TerraformOutput ssh_public_key_id)

if (-not $resourceGroup) {
    Write-Warning "No resources deployed in workspace $(terraform workspace show), exiting"
    exit
}
Pop-Location

if ($sshPrivateKeyID) {
    $sshPrivateKey = $(az keyvault secret show --id $sshPrivateKeyID --query "value" -o tsv)
}
if ($sshPublicKeyID) {
    $sshPublicKey = $(az sshkey show --ids $sshPublicKeyID --query "publicKey" -o tsv)
}
if (-not $sshPrivateKey) {
    Write-Warning "Private SSH key not found, exiting"
    exit
}
if (-not $sshPublicKey) {
    Write-Warning "Public SSH key not found, exiting"
    exit
}

if ($Keyname) {
    $sshPrivateFile = $Keyname
    $sshPublicFile = "${Keyname}.pub"
    $keyDirectory = (Split-Path $sshPrivateFile -Parent)

    if ((-not (Test-Path $keyDirectory)) -and $Force) {
        New-Item -ItemType Directory -Force -Path $keyDirectory | Out-Null 
    }
    if (!$Force -and (Test-Path $sshPrivateFile)) {
        Write-Warning "${sshPrivateFile} already exists, exiting"
        exit
    }
    if (!$Force -and (Test-Path $sshPublicFile)) {
        Write-Warning "${sshPublicFile} already exists, exiting"
        exit
    }

    Write-Host "Saving ${sshPrivateFile}..."
    Set-Content -Path $sshPrivateFile -Value $sshPrivateKey -Force:$Force
    if (Get-Command chmod -ErrorAction SilentlyContinue) {
        chmod 600 $sshPrivateFile
    }
    Write-Host "Saving ${sshPublicFile}..."
    Set-Content -Path $sshPublicFile  -Value $sshPublicKey -Force:$Force
} else {
    Write-Information "Private Key:`n${sshPrivateKey}"
    Write-Information "Public Key:`n${sshPublicKey}"
}