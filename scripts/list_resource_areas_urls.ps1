#!/usr/bin/env pwsh

### Arguments
param ( 
    [parameter(Mandatory=$true)][string]$Organization,
    [parameter(Mandatory=$false)][string]$UrlMatch
) 

$response = (Invoke-WebRequest "https://dev.azure.com/${Organization}/_apis/resourceareas/")

$locationInfo = (($response.Content | ConvertFrom-Json).value | Select-Object -Property name, locationUrl | Sort-Object -Property Name)
if ($UrlMatch) {
    $locationInfo = ($locationInfo | Where-Object locationUrl -Match $UrlMatch)
}
$locationInfo | Format-Table