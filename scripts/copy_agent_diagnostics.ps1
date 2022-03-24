#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$true)][string]$FilesSourceUrl,
    [parameter(Mandatory=$true)][string]$BlobTargetUrl,
    [parameter(Mandatory=$false)][string]$LocalPath
) 

function Create-SasToken (
    [parameter(Mandatory=$true)][string]$StorageAccountName,   
    [parameter(Mandatory=$true)][string]$ResourceGroupName,   
    [parameter(Mandatory=$true)][string]$SubscriptionId,
    [parameter(Mandatory=$false)][switch]$Write,
    [parameter(Mandatory=$false)][switch]$Delete,
    [parameter(Mandatory=$false)][int]$SasTokenValidityDays=1
) {
    # Add firewall rule on storage account
    Write-Information "Generating SAS token for '$StorageAccountName'..."
    $sasPermissions = "lr"
    if ($Write) {
        $sasPermissions += "acuw"
    }
    if ($Delete) {
        $sasPermissions += "d"
    }
    az storage account generate-sas --account-key $(az storage account keys list -n $StorageAccountName -g $ResourceGroupName --subscription $SubscriptionId --query "[0].value" -o tsv) `
                                    --account-name $StorageAccountName `
                                    --expiry "$([DateTime]::UtcNow.AddDays($SasTokenValidityDays).ToString('s'))Z" `
                                    --permissions $sasPermissions `
                                    --resource-types co `
                                    --services bf `
                                    --subscription $SubscriptionId `
                                    --start "$([DateTime]::UtcNow.AddDays(-30).ToString('s'))Z" `
                                    -o tsv | Set-Variable storageAccountToken
    Write-Debug "storageAccountToken: $storageAccountToken"
    Write-Verbose "Generated SAS token for '$StorageAccountName'"
    return $storageAccountToken
}
function Get-StorageAccount (
    [parameter(Mandatory=$false)][string]$StorageAccountName,
    [parameter(Mandatory=$false)][string]$Url
) {
    if ($Url) {
        $StorageAccountName = Parse-StorageAccountName $Url
    }

    az graph query -q "resources | where type =~ 'microsoft.storage/storageaccounts' and name == '$StorageAccountName'" `
                   -a `
                   --query "data" `
                   -o json | ConvertFrom-Json | Set-Variable storageAccount

    Write-Debug "storageAccount: $storageAccount"
    return $storageAccount
}

function Parse-StorageAccountName (
    [parameter(Mandatory=$true)][string]$Url
) {
    if ($Url -notmatch "https://(?<name>\w+)\.(blob|file).core.windows.net/(?<container>\w+)/?[\w|/]*") {
        Write-Error "Target '$Url' is not a storage URL"
        return
    }
    $storageAccountName = $matches["name"]
    Write-Debug "storageAccountName: $storageAccountName"
    return $storageAccountName
}

if (!$FilesSourceUrl.EndsWith("/")) {
    $FilesSourceUrl += '/'
}
if (!$BlobTargetUrl.EndsWith("/")) {
    $BlobTargetUrl += '/'
}

$sourceStorageAccount = Get-StorageAccount -Url $FilesSourceUrl
$sourceStorageAccountToken = Create-SasToken -StorageAccountName $sourceStorageAccount.name `
                                             -ResourceGroupName $sourceStorageAccount.resourceGroup `
                                             -SubscriptionId $sourceStorageAccount.subscriptionId
$targetStorageAccount = Get-StorageAccount -Url $BlobTargetUrl
$targetStorageAccountToken = Create-SasToken -StorageAccountName $targetStorageAccount.name `
                                             -ResourceGroupName $targetStorageAccount.resourceGroup `
                                             -SubscriptionId $targetStorageAccount.subscriptionId `
                                             -Write
$sourceUrlWithToken = "${FilesSourceUrl}?${sourceStorageAccountToken}"
Write-Debug "sourceUrlWithToken: $sourceUrlWithToken"
$targetUrlWithToken = "${BlobTargetUrl}?${targetStorageAccountToken}"
Write-Debug "targetUrlWithToken: $targetUrlWithToken"
azcopy copy "${sourceUrlWithToken}" `
            "${targetUrlWithToken}" `
            --overwrite false `
            --recursive