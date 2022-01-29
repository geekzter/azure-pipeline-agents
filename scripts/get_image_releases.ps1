#!/usr/bin/env pwsh
<#
.SYNOPSIS 
    Installs Apple US International Keyboard layout for Windows
 
.DESCRIPTION 
    Downloads latest releases from https://github.com/repos/actions/virtual-environments
#> 
param ( 
    [parameter(Mandatory=$false)][switch]$DownloadAndExtract=$false,
    [parameter(Mandatory=$false)][string]$ExtractDirectory
) 

if ($DownloadAndExtract) {
    if ($ExtractDirectory) {
        if (!(Test-Path $ExtractDirectory)) {
            Write-Warning "$ExtractDirectory does not exist, exiting"
            exit
        }
    } else {
        New-Item -ItemType Directory -Path (Join-Path $([System.IO.Path]::GetTempPath()) $([System.Guid]::NewGuid())) | Select-Object -ExpandProperty FullName | Set-Variable ExtractDirectory
    }
}


$releasesResponse = (Invoke-RestMethod -Uri https://api.github.com/repos/actions/virtual-environments/releases)

foreach ($tag in @("ubuntu18","ubuntu20","win19","win22")) {
#foreach ($tag in @("ubuntu20")) {
    $release = $releasesResponse | Where-Object -Property tag_name -Match $tag | Select-Object -First 1
    $version = $release.tag_name.Split("/")[1]
    Write-Host "$tag version $version"

    if ($DownloadAndExtract) {
        $releaseExtractDirectory = Join-Path $ExtractDirectory $tag $version
        New-Item -ItemType Directory -Path $releaseExtractDirectory -Force -ErrorAction SilentlyContinue | Out-Null
        $archiveFullName = "$(Join-Path $releaseExtractDirectory $version).zip"
        Write-Host "Downloading $tag version $version source archive to ${archiveFullName}..."
        Invoke-Webrequest -Uri $release.zipball_url -OutFile $archiveFullName -UseBasicParsing 
        Write-Host "Extracting ${archiveFullName} to ${releaseExtractDirectory}..."
        Expand-Archive -Path $archiveFullName -DestinationPath $releaseExtractDirectory
        Get-ChildItem $releaseExtractDirectory | Format-Table
    }
}

