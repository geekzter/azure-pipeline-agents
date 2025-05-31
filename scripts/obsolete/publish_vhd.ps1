#!/usr/bin/env pwsh

<# 
.SYNOPSIS 
    Finds VHD in given Resource Group and publishes it in a Shared Image Gallery
 
.DESCRIPTION 
    The image build script (https://github.com/actions/runner-images/blob/main/helpers/GenerateResourcesAndImage.ps1)
    creates a storage account, storage container and VHD. 
    This scipt finds the VHD based on the Resource Group name that is input to aforementioned script. 
    The VHD found will be published, creating required artifacts including the Shared Image Gallery itself if it does not exist yet.

.EXAMPLE
    ./publish_vhd.ps1 -SourceVHDUrl "https://packer12345.blob.core.windows.net/system/Microsoft.Compute/Images/images/packer-osDisk.00000000-0000-0000-0000-000000000000.vhd?se=2022-02-07&sp=racwdl&sv=2018-11-09&sr=c&skoid=00000000-0000-0000-0000-000000000000&sktid=00000000-0000-0000-0000-000000000000&skt=2022-01-31T10%3A39%3A58Z&ske=2022-02-07T00%3A00%3A00Z&sks=b&skv=2018-11-09&sig=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX3D" `
                      -GalleryResourceGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Shared" 
                      -GalleryName OurGallery -ImageDefinitionName Ubuntu2404 -Publisher PrivatePipelineImages -Offer Ubuntu -SKU 2004 -OsType linux
#> 
#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$false)][string]$SourceVHDUrl=$env:IMAGE_VHD_URL,
    [parameter(Mandatory=$true)][string]$GalleryResourceGroupId,
    [parameter(Mandatory=$false)][string]$GalleryName,
    [parameter(Mandatory=$false,HelpMessage="VHD's are copied here")][string]$TargetVHDStorageAccountName,
    [parameter(Mandatory=$false,HelpMessage="VHD's are copied here")][string]$TargetVHDStorageContainerName,
    [parameter(Mandatory=$false,HelpMessage="VHD's are copied here")][string]$TargetVHDStorageResourceGroupName,
    [parameter(Mandatory=$true)][string]$ImageDefinitionName,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][hashtable]$ImageDefinitionVersionTags,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$Publisher,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$Offer,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$SKU,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string]$OsType,
    [parameter(Mandatory=$false,HelpMessage="Only required to create image version")][string[]]$TargetRegion,
    [parameter(Mandatory=$false,HelpMessage="Only use to create image version")][switch]$ExcludeFromLatest
) 
$stopwatch = [system.diagnostics.stopwatch]::StartNew()
Write-Verbose $MyInvocation.line 

$galleryResourceGroupName = $GalleryResourceGroupId.Split("/")[-1]
$gallerySubscriptionId = $GalleryResourceGroupId.Split("/")[2]
$tags=@("application=Pipeline Agents","provisioner=azure-cli")
# $createSAS = !((Test-Path env:AZCOPY_SPA_*) -or (Test-Path env:AZCOPY_MSI_*))

# Input validation
if (!$GalleryName) {
    Write-Warning "`nShared Image Gallery not specified, exiting"
    exit
}
if (!$SourceVHDUrl) {
    Write-Error "`nSourceVHDUrl not specified, exiting"
    exit
}
if ($SourceVHDUrl -match "^https://(?<account>[\w]+)\.") {
    $sourceVHDStorageAccountName = $matches["account"]
} else {
    Write-Warning "`nCould not parse storage account name from SourceVHDUrl $SourceVHDUrl, exiting"
    exit
}
az group list --subscription $gallerySubscriptionId --query "[?name=='$galleryResourceGroupName']" -o json | ConvertFrom-Json | Set-Variable galleryResourceGroup
if (!$galleryResourceGroup) {
    Write-Warning "`nShared Gallery Resource Group '$galleryResourceGroupName' does not exist, exiting"
    exit
}
az sig list --resource-group $galleryResourceGroupName --subscription $gallerySubscriptionId --query "[?name=='$GalleryName']" -o json | ConvertFrom-Json | Set-Variable gallery
if (!$gallery) {
    Write-Host "`nShared Gallery '$GalleryName' does not exist yet, exiting"
    exit
}

az sig image-definition list --gallery-name $GalleryName `
                             --resource-group $galleryResourceGroupName `
                             --subscription $gallerySubscriptionId `
                             --query "[?name=='$ImageDefinitionName']" `
                             -o json | ConvertFrom-Json | Set-Variable imageDefinition
if (!$imageDefinition) {
    if (!$Publisher -or !$Offer -or !$SKU -or !$OsType) {
        Write-Warning "`nImage Definition '$ImageDefinitionName' does not exist yet and arguments to create it were not (all) not specified, exiting"
        exit
    }
    Write-Host "`nImage Definition '$ImageDefinitionName' (${Publisher}/${Offer}/${SKU}) does not exist yet, creating it..."
    az sig image-definition create --gallery-image-definition $ImageDefinitionName `
                                   --gallery-name $GalleryName `
                                   --location $gallery.location `
                                   --resource-group $galleryResourceGroupName `
                                   --subscription $gallerySubscriptionId `
                                   --publisher $Publisher --offer $Offer --sku $SKU `
                                   --os-type $OsType --os-state Generalized `
                                   --tags $tags | ConvertFrom-Json | Set-Variable imageDefinition
    Write-Host "`nImage Definition '$ImageDefinitionName' (${Publisher}/${Offer}/${SKU}) does not exist yet, created after $($stopwatch.Elapsed.ToString("m'm's's'"))"
}

if (!$ImageDefinitionVersionTags -or !$ImageDefinitionVersionTags.ContainsKey("versionlabel")) {
    Write-Warning "`nImageDefinitionVersionTags not specified with versionlabel, exiting"
    exit
}

az sig image-version list --gallery-image-definition $ImageDefinitionName `
                          --gallery-name $GalleryName `
                          --resource-group $galleryResourceGroupName --query "[].name" -o json `
                          --subscription $gallerySubscriptionId `
                          | ConvertFrom-Json `
                          | ForEach-Object {[version]$_} `
                          | Sort-Object -Descending | Select-Object -First 1 `
                          | Set-Variable latestVersion
# Increment version
[version]$newVersion = New-Object version $latestVersion.Major, $latestVersion.Minor, ($latestVersion.Build+1)
$newVersionString = $newVersion.ToString()

[System.Collections.ArrayList]$imageTags = $tags.Clone()
foreach ($tagName in $ImageDefinitionVersionTags.Keys) {
    $tagValue = $ImageDefinitionVersionTags[$tagName]
    $imageTags.Add("${tagName}=${tagValue}") | Out-Null
}
Write-Host "`nTags that will be applied to version ${newVersionString} of Image Definition '$ImageDefinitionName':"
$imageTags.GetEnumerator() | Sort-Object -Property Name | Format-Table

if ($TargetVHDStorageAccountName -and $TargetVHDStorageContainerName -and $TargetVHDStorageResourceGroupName) {
    # Use intermediate storage account (e.g. in different tenant from source storage account)
    $targetVHDPath = "${Publisher}/${Offer}/${SKU}/${newVersionString}.vhd"
    $targetVHDUrl = "https://${TargetVHDStorageAccountName}.blob.core.windows.net/${TargetVHDStorageContainerName}/${targetVHDPath}"
    # if ($createSAS) {
        az storage account generate-sas --account-key $(az storage account keys list -n $TargetVHDStorageAccountName -g $TargetVHDStorageResourceGroupName --subscription $gallerySubscriptionId --query "[0].value" -o tsv) `
                                        --account-name $TargetVHDStorageAccountName `
                                        --expiry "$([DateTime]::UtcNow.AddDays(7).ToString('s'))Z" `
                                        --permissions "lracuw"`
                                        --resource-types co `
                                        --services b `
                                        --subscription $gallerySubscriptionId `
                                        --start "$([DateTime]::UtcNow.AddDays(-30).ToString('s'))Z" `
                                        -o tsv | Set-Variable targetSASToken    
        $targetVHDUrlWithToken = "${targetVHDUrl}?${targetSASToken}"
    # } else {
    #     $targetVHDUrlWithToken = "${targetVHDUrl}"
    # }
    Write-Host "`nCopying '$SourceVHDUrl' to '$targetVHDUrlWithToken'..."
    Write-Host "azcopy copy `"${SourceVHDUrl}`" `"${targetVHDUrlWithToken}`" --overwrite true "
    azcopy copy "${SourceVHDUrl}" "${targetVHDUrlWithToken}" --overwrite true 
    Write-Host "Copy '$SourceVHDUrl' to '$targetVHDUrlWithToken' completed after $($stopwatch.Elapsed.ToString("m'm's's'"))"

    $vhdGalleryImportUrl = $targetVHDUrl
    $vhdGalleryImportStorageAccountName = $TargetVHDStorageAccountName
} else {
    # Images cannot be created from Shared Access Signature (SAS) URI blobs
    if ("${SourceVHDUrl}" -match "\.vhd\?") {
        Write-Warning "Images cannot be created from Shared Access Signature (SAS) URI blobs, removing SAS"
        $SourceVHDUrl = ($SourceVHDUrl -replace "\?.*$","")
    }
    $vhdGalleryImportUrl = $SourceVHDUrl
    $vhdGalleryImportStorageAccountName = $sourceVHDStorageAccountName
}

Write-Host "`nCreating Image version ${newVersionString} of Image Definition '$ImageDefinitionName'..."
$TargetRegion ??= ((@($gallery.location,$galleryResourceGroup.location) | Get-Unique) -join ",")
az sig image-version create --exclude-from-latest $ExcludeFromLatest.ToString().ToLower() `
                            --gallery-image-definition $ImageDefinitionName `
                            --gallery-name $GalleryName `
                            --gallery-image-version $newVersionString `
                            --location $gallery.location `
                            --no-wait `
                            --resource-group $galleryResourceGroupName `
                            --subscription $gallerySubscriptionId `
                            --target-regions $TargetRegion `
                            --os-vhd-uri "${vhdGalleryImportUrl}" `
                            --os-vhd-storage-account $vhdGalleryImportStorageAccountName `
                            --tags $imageTags | ConvertFrom-Json | Set-Variable imageVersion
Write-Host "`nImage version ${newVersionString} of Image Definition '$ImageDefinitionName' creation submitted after $($stopwatch.Elapsed.ToString("m'm's's'"))"
Write-Host "Waiting for image creation and replication to regions (long-running operation: ${TargetRegion}) to finish..."
az sig image-version wait   --custom "[?provisioningState=='Succeeded']" `
                            --gallery-image-definition $ImageDefinitionName `
                            --gallery-name $GalleryName `
                            --gallery-image-version $newVersionString `
                            --resource-group $galleryResourceGroupName
Write-Host "Image version ${newVersionString} of Image Definition '$ImageDefinitionName' created and replicated after $($stopwatch.Elapsed.ToString("m'm's's'"))"

$imageVersion | Format-List