#!/usr/bin/env pwsh

param ( 
  [parameter(Mandatory=$true)][string]$ResourceGroupName,
  [parameter(Mandatory=$true)][string]$StorageAccountName,
  [parameter(Mandatory=$true)][string]$StorageAccountSasToken,
  [parameter(Mandatory=$true)][string]$Subscription=$env:ARM_SUBSCRIPTION_ID,
  [parameter(Mandatory=$true)][string]$VMScaleSetName
) 
$vmssResourceID = "/subscriptions/${Subscription}/resourceGroups/${ResourceGroupName}/providers/Microsoft.Compute/virtualMachineScaleSets/${VMScaleSetName}"
Write-Debug "`$vmssResourceID: $vmssResourceID"

$settingsFile = New-TemporaryFile
$settings = $(az vmss diagnostics get-default-config)
# Write-Debug "`$settings: $settings"
$settings = $settings -replace "__DIAGNOSTIC_STORAGE_ACCOUNT__", $StorageAccountName
$settings = $settings -replace "__VM_OR_VMSS_RESOURCE_ID__", $vmssResourceID
$settings | Out-File $settingsFile
Write-Debug "`$settings: $settings"
Write-Debug "`$settingsFile: $(Get-Content $settingsFile)"

$protectedSettingsFile = New-TemporaryFile
$protectedSettings = @{
  storageAccountName     = $StorageAccountName
  storageAccountSasToken = "$StorageAccountSasToken"
} | ConvertTo-Json
$protectedSettings | Out-File $protectedSettingsFile
Write-Debug "`$protectedSettings: $protectedSettings"
Write-Debug "`$protectedSettingsFile: $(Get-Content $protectedSettingsFile)"

az vmss diagnostics set --resource-group $ResourceGroupName --vmss-name $VMScaleSetName --settings $settingsFile --protected-settings $protectedSettingsFile --subscription $Subscription
