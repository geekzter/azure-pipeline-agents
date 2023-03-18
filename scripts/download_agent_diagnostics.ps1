#!/usr/bin/env pwsh
param ( 
    [parameter(Mandatory=$false)][string]$FilesShareUrl,
    [parameter(Mandatory=$false)][string]$LocalPath,
    [parameter(Mandatory=$false)][switch]$Purge,
    [parameter(Mandatory=$false)][string]$Workspace=($env:TF_WORKSPACE ?? "default"),
    [parameter(Mandatory=$false)][ValidateNotNull()][int]$MaxMegabitsPerSecond=4
) 
. (Join-Path $PSScriptRoot functions.ps1)
function Create-SasToken (
    [parameter(Mandatory=$true)][string]$StorageAccountName,   
    [parameter(Mandatory=$true)][string]$ResourceGroupName,   
    [parameter(Mandatory=$true)][string]$SubscriptionId,
    [parameter(Mandatory=$false)][int]$SasTokenValidityDays=1
) {
    # Add firewall rule on storage account
    Write-Information "Generating SAS token for '$StorageAccountName'..."
    az storage account generate-sas --account-key $(az storage account keys list -n $StorageAccountName -g $ResourceGroupName --subscription $SubscriptionId --query "[0].value" -o tsv) `
                                    --account-name $StorageAccountName `
                                    --expiry "$([DateTime]::UtcNow.AddDays($SasTokenValidityDays).ToString('s'))Z" `
                                    --permissions dlr `
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
        exit
    }
    $storageAccountName = $matches["name"]
    Write-Debug "storageAccountName: $storageAccountName"
    return $storageAccountName
}

Login-Az -DisplayMessages

# Process parameters
$terraformDirectory = (Join-Path (Split-Path -parent -Path $PSScriptRoot) "terraform")
Push-Location $terraformDirectory
if (!$env:TF_WORKSPACE) {
    terraform workspace select $Workspace
}
if (!$FilesShareUrl) {
    $FilesShareUrl = (Get-TerraformOutput agent_diagnostics_file_share_url)
}
if (!$FilesShareUrl) {
    Write-Warning "Files share has not been created (yet), nothing to do"
    exit
}
if (!$FilesShareUrl.EndsWith("/")) {
    $FilesShareUrl += '/'
}
Pop-Location

if (!$LocalPath) {
    $LocalPath = (Join-Path (Split-Path $PSScriptRoot -Parent) data $Workspace agent)
    New-Item $LocalPath -ItemType "directory" -Force -ErrorAction SilentlyContinue | Out-Null
}

# Main
$sourceStorageAccount = Get-StorageAccount -Url $FilesShareUrl
$sourceStorageAccountToken = Create-SasToken -StorageAccountName $sourceStorageAccount.name `
                                             -ResourceGroupName $sourceStorageAccount.resourceGroup `
                                             -SubscriptionId $sourceStorageAccount.subscriptionId
$sourceUrlWithToken = "${FilesShareUrl}?${sourceStorageAccountToken}"
Write-Debug "sourceUrlWithToken: $sourceUrlWithToken"

if (!(Test-Path $LocalPath)) {
    "Local path '{0}' does not exist" -f $LocalPath | Write-Error
    exit
}
azcopy copy "${sourceUrlWithToken}" `
            $LocalPath `
            --cap-mbps $MaxMegabitsPerSecond `
            --overwrite false `
            --recursive

if ($LASTEXITCODE -eq 1) {
    Write-Warning "azcopy failed copying files (${LASTEXITCODE})"
    $defaultPurgeChoice = 1
} elseif ($LASTEXITCODE -ne 0) {
    Write-Warning "azcopy failed copying files (${LASTEXITCODE}), exiting"
    exit $exitCode
}

if ($Purge) {
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Purge", "Purge files from the share?")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Exit", "Abort purge operation")
    )
    $defaultPurgeChoice ??= 0 
    $decision = $Host.UI.PromptForChoice("Continue", "Do you wish to proceed puging files from ${FilesShareUrl}?", $choices, $defaultPurgeChoice)

    if ($decision -eq 0) {
        Write-Host "$($choices[$decision].HelpMessage)"
    } else {
        Write-Host "$($PSStyle.Formatting.Warning)$($choices[$decision].HelpMessage)$($PSStyle.Reset)"
        exit                    
    }
    azcopy rm "${sourceUrlWithToken}" --recursive
}