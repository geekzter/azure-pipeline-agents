#!/usr/bin/env pwsh

<# 
.SYNOPSIS 
    Finds VHD in given Resource Group
 
.DESCRIPTION 
    The image build script (https://github.com/actions/virtual-environments/blob/main/helpers/GenerateResourcesAndImage.ps1)
    creates a storage account, storage container and VHD. This scipt finfs the VHD based on the Resource Group name that is input to aforementioned script.

.EXAMPLE
    
#> 
#Requires -Version 7

### Arguments
param ( 
    [parameter(Mandatory=$false,HelpMessage="Initialize Terraform backend, modules & provider")][string]$ResourceGroup
) 

az storage account list -g $ResourceGroup --query "[0]" -o json | ConvertFrom-Json | Set-Variable storageAccount
$storageAccountKey =  $(az storage account keys list -n $storageAccount.name --query "[0].value" -o tsv)
$vhdPath = $(az storage blob directory list -c system -d "Microsoft.Compute/Images/images" --account-name $storageAccount.name --account-key $storageAccountKey --query "[?ends_with(name,'vhd')].name" -o tsv)
$vhdUrl = "$($storageAccount.primaryEndpoints.blob)$vhdPath"
$vhdUrl
