function AzLogin (
    [parameter(Mandatory=$false)][switch]$DisplayMessages=$false
) {
    # Are we logged into the wrong tenant?
    Invoke-Command -ScriptBlock {
        $Private:ErrorActionPreference = "Continue"
        if ($env:ARM_TENANT_ID) {
            $script:loggedInTenantId = $(az account show --query tenantId -o tsv 2>$null)
        }
    }
    if ($loggedInTenantId -and ($loggedInTenantId -ine $env:ARM_TENANT_ID)) {
        Write-Warning "Logged into tenant $loggedInTenantId instead of $env:ARM_TENANT_ID (`$env:ARM_TENANT_ID), logging off az session"
        az logout -o none
    }

    # Are we logged in?
    Invoke-Command -ScriptBlock {
        $Private:ErrorActionPreference = "Continue"
        # Test whether we are logged in
        $script:loginError = $(az account show -o none 2>&1)
        if (!$loginError) {
            $Script:userType = $(az account show --query "user.type" -o tsv)
            if ($userType -ieq "user") {
                # Test whether credentials have expired
                $Script:userError = $(az ad signed-in-user show -o none 2>&1)
            } 
        }
    }
    $login = ($loginError -or $userError)
    if ($env:CODESPACES -ieq "true") {
        $azLoginSwitches = "--use-device-code"
    }
    # Set Azure CLI context
    if ($login) {
        if ($env:ARM_TENANT_ID) {
            az login -t $env:ARM_TENANT_ID -o none $($azLoginSwitches)
        } else {
            az login -o none $($azLoginSwitches)
        }
    }

    if ($DisplayMessages) {
        if ($env:ARM_SUBSCRIPTION_ID -or ($(az account list --query "length([])" -o tsv) -eq 1)) {
            Write-Host "Using subscription '$(az account show --query "name" -o tsv)'"
        } else {
            if ($env:TF_IN_AUTOMATION -ine "true") {
                # Active subscription may not be the desired one, prompt the user to select one
                $subscriptions = (az account list --query "sort_by([].{id:id, name:name},&name)" -o json | ConvertFrom-Json) 
                $index = 0
                $subscriptions | Format-Table -Property @{name="index";expression={$script:index;$script:index+=1}}, id, name
                Write-Host "Set `$env:ARM_SUBSCRIPTION_ID to the id of the subscription you want to use to prevent this prompt" -NoNewline

                do {
                    Write-Host "`nEnter the index # of the subscription you want Terraform to use: " -ForegroundColor Cyan -NoNewline
                    $occurrence = Read-Host
                } while (($occurrence -notmatch "^\d+$") -or ($occurrence -lt 1) -or ($occurrence -gt $subscriptions.Length))
                $env:ARM_SUBSCRIPTION_ID = $subscriptions[$occurrence-1].id
            
                Write-Host "Using subscription '$($subscriptions[$occurrence-1].name)'" -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            } else {
                Write-Host "Using subscription '$(az account show --query "name" -o tsv)', set `$env:ARM_SUBSCRIPTION_ID if you want to use another one"
            }
        }
    }

    if ($env:ARM_SUBSCRIPTION_ID) {
        az account set -s $env:ARM_SUBSCRIPTION_ID -o none
    }

    # Populate Terraform azurerm variables where possible
    if ($userType -ine "user") {
        # Pass on pipeline service principal credentials to Terraform
        $env:ARM_CLIENT_ID       ??= $env:servicePrincipalId
        $env:ARM_CLIENT_SECRET   ??= $env:servicePrincipalKey
        $env:ARM_TENANT_ID       ??= $env:tenantId
        # Get from Azure CLI context
        $env:ARM_TENANT_ID       ??= $(az account show --query tenantId -o tsv)
        $env:ARM_SUBSCRIPTION_ID ??= $(az account show --query id -o tsv)
    }
    # Variables for Terraform azurerm Storage backend
    if (!$env:ARM_ACCESS_KEY -and !$env:ARM_SAS_TOKEN) {
        if ($env:TF_VAR_backend_storage_account -and $env:TF_VAR_backend_storage_container) {
            $env:ARM_SAS_TOKEN=$(az storage container generate-sas -n $env:TF_VAR_backend_storage_container --as-user --auth-mode login --account-name $env:TF_VAR_backend_storage_account --permissions acdlrw --expiry (Get-Date).AddDays(7).ToString("yyyy-MM-dd") -o tsv)
        }
    }
}

function DownloadAndExtract-VPNProfile (
    [parameter(Mandatory=$true)][string]$GatewayID
) {
    Write-Host "`nGenerating VPN profiles..."
    $vpnPackageUrl = $(az network vnet-gateway vpn-client generate --ids $gatewayId --authentication-method EAPTLS -o tsv)

    # Download VPN Profile
    Write-Host "Downloading VPN profiles..."
    $packageFile = New-TemporaryFile
    Invoke-WebRequest -UseBasicParsing -Uri $vpnPackageUrl -OutFile $packageFile

    $tempPackagePath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    $null = New-Item -ItemType "directory" -Path $tempPackagePath
    # Extract package archive
    Expand-Archive -Path $packageFile -DestinationPath $tempPackagePath
    Write-Verbose "Package extracted at $tempPackagePath"

    return $tempPackagePath
}

$certificateKeytoFileMapping  = @{
    "client_cert_private_pem" = "client_cert.key"
    "client_cert_public_pem"  = "client_cert.pem"
    "client_cert_merged_pem"  = "client_cert_merged.pem"
    "root_cert_private_pem"   = "root_cert.key"
    "root_cert_public_pem"    = "root_cert.pem"
    "root_cert_merged_pem"    = "root_cert_merged.pem"
}

function Export-CertificateFromTerraform(
    [parameter(Mandatory=$true)][string]$OutputVariable,
    [parameter(Mandatory=$true)][string]$CertificateDirectory
) {
    $certificateData = (Get-TerraformOutput $OutputVariable)
    Write-Debug "${OutputVariable}:`n${certificateData}"

    $certificateFileName = (Join-Path $CertificateDirectory $certificateKeytoFileMapping[$OutputVariable])

    Set-Content -Path $certificateFileName -Value $certificateData -Force
    Write-Debug "Data written to ${certificateFileName}"
}

function Export-CertificatesFromTerraform() {
    $certificateDirectory = Get-CertificatesDirectory

    Push-Location (Get-TerraformDirectory)
    try {
        Export-CertificateFromTerraform -OutputVariable "client_cert_private_pem" -CertificateDirectory $certificateDirectory
        Export-CertificateFromTerraform -OutputVariable "client_cert_public_pem" -CertificateDirectory $certificateDirectory
        Export-CertificateFromTerraform -OutputVariable "client_cert_merged_pem" -CertificateDirectory $certificateDirectory
        Export-CertificateFromTerraform -OutputVariable "root_cert_private_pem" -CertificateDirectory $certificateDirectory
        Export-CertificateFromTerraform -OutputVariable "root_cert_public_pem" -CertificateDirectory $certificateDirectory
        Export-CertificateFromTerraform -OutputVariable "root_cert_merged_pem" -CertificateDirectory $certificateDirectory
    } finally {
        Pop-Location
    }
    
    return $certificateDirectory
}

function Get-CertificatesDirectory() {
    $directory = (Join-Path (Split-Path $PSScriptRoot -Parent) "data" (Get-TerraformWorkspace) "certificates")
    if (!(Test-Path $directory)) {
        $null = New-Item -ItemType Directory -Force -Path $directory 
    }

    return $directory
}

function Get-TerraformDirectory {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) "terraform")
}

function Get-TerraformOutput (
    [parameter(Mandatory=$true)][string]$OutputVariable
) {
    Invoke-Command -ScriptBlock {
        $Private:ErrorActionPreference = "SilentlyContinue"
        Write-Verbose "terraform output -raw ${OutputVariable}: evaluating..."
        $result = $(terraform output -raw $OutputVariable 2>$null)
        if ($result -match "\[\d+m") {
            # Terraform warning, return null for missing output
            Write-Verbose "terraform output ${OutputVariable}: `$null (${result})"
            return $null
        } else {
            Write-Verbose "terraform output ${OutputVariable}: ${result}"
            return $result
        }
    }
}

function Get-TerraformWorkspace () {
    Push-Location (Get-TerraformDirectory)
    try {
        return $(terraform workspace show)
    } finally {
        Pop-Location
    }
}

function Install-Certificates(
    [parameter(Mandatory=$true)][string]$CertPassword
) {
    $certificateDirectory = Export-CertificatesFromTerraform

    # $clientCertificateCommonName = (Get-TerraformOutput "client_cert_common_name")
    # $clientCertMergedPEMFile = (Get-TerraformOutput "client_cert_merged_pem_file")
    # $clientCertPublicPEMFile = (Get-TerraformOutput "client_cert_pem_file")
    # $rootCertificateCommonName = (Get-TerraformOutput "root_cert_common_name")
    # $rootCertPublicPEMFile = (Get-TerraformOutput "root_cert_pem_file")

    $clientCertMergedPEMFile      = (Join-Path $certificateDirectory $certificateKeytoFileMapping["client_cert_merged_pem"])
    $clientCertPublicPEMFile      = (Join-Path $certificateDirectory $certificateKeytoFileMapping["client_cert_public_pem"])
    $rootCertPublicPEMFile        = (Join-Path $certificateDirectory $certificateKeytoFileMapping["root_cert_public_pem"])

    Push-Location (Get-TerraformDirectory)
    $clientCertificateCommonName  = (Get-TerraformOutput "client_cert_common_name")
    $rootCertificateCommonName    = (Get-TerraformOutput "root_cert_common_name")
    Pop-Location

    if ($IsMacOS) {
        Install-CertificatesMacOS   -CertPassword $CertPassword `
                                    -ClientCertificateCommonName $clientCertificateCommonName `
                                    -ClientCertMergedPEMFile $clientCertMergedPEMFile `
                                    -RootCertificateCommonName $rootCertificateCommonName `
                                    -RootCertPublicPEMFile $rootCertPublicPEMFile
        return
    }
    if ($IsWindows) {
        Install-CertificatesWindows -CertPassword $CertPassword `
                                    -ClientCertificateCommonName $clientCertificateCommonName `
                                    -ClientCertPublicPEMFile $clientCertPublicPEMFile `
                                    -RootCertificateCommonName $rootCertificateCommonName `
                                    -RootCertPublicPEMFile $rootCertPublicPEMFile
        return
    }
    Write-Error "Skipping certificate import on $($PSversionTable.OS)"
}

function Install-CertificatesMacOS (
    [parameter(Mandatory=$true)][string]$CertPassword,
    [parameter(Mandatory=$true)][string]$ClientCertificateCommonName,
    [parameter(Mandatory=$true)][string]$ClientCertMergedPEMFile,
    [parameter(Mandatory=$true)][string]$RootCertificateCommonName,
    [parameter(Mandatory=$true)][string]$RootCertPublicPEMFile
) {
    # Install certificates
    #security unlock-keychain ~/Library/Keychains/login.keychain
    if (Test-Path $RootCertPublicPEMFile) {
        if (security find-certificate -c $RootCertificateCommonName 2>$null) {
            Write-Warning "Certificate with common name $RootCertificateCommonName already exixts"
            # Prompt to overwrite
            Write-Host "Continue importing ${RootCertPublicPEMFile}? Please reply 'yes' - null or N skips import" -ForegroundColor Cyan
            $proceedanswer = Read-Host 
            $skipRootCertImport = ($proceedanswer -ne "yes")
        } 

        if (!$skipRootCertImport) {
            Write-Host "Importing root certificate ${RootCertPublicPEMFile} with common name ${RootCertificateCommonName}..."
            security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain $RootCertPublicPEMFile
        }
    } else {
        Write-Warning "Certificate $RootCertPublicPEMFile does not exist, have you run 'terraform apply' yet?"
        return
    }
    if (Test-Path $ClientCertMergedPEMFile) {
        Write-Information "Looking for existing certificate(s) with common name ${ClientCertificateCommonName}..."
        if (security find-certificate -c $ClientCertificateCommonName 2>$null) {
            Write-Warning "Certificate with common name $ClientCertificateCommonName already exixts"
            # Prompt to overwrite
            Write-Host "Continue importing ${ClientCertMergedPEMFile}? Please reply 'yes' - null or N skips import" -ForegroundColor Cyan
            $proceedanswer = Read-Host 
            $skipClientCertImport = ($proceedanswer -ne "yes")
        } 

        if (!$skipClientCertImport) {
            Write-Host "Importing client certificate ${ClientCertMergedPEMFile} with common name ${ClientCertificateCommonName}..."
            security import $ClientCertMergedPEMFile -P $certPassword
        }
    } else {
        Write-Warning "Certificate $ClientCertMergedPEMFile does not exist, have you run 'terraform apply' yet?"
        return
    }
}

function Install-CertificatesWindows (
    [parameter(Mandatory=$true)][string]$CertPassword,
    [parameter(Mandatory=$true)][string]$ClientCertificateCommonName,
    [parameter(Mandatory=$true)][string]$ClientCertPublicPEMFile,
    [parameter(Mandatory=$true)][string]$RootCertificateCommonName,
    [parameter(Mandatory=$true)][string]$RootCertPublicPEMFile
) {
    if (!(Get-Command certutil -ErrorAction SilentlyContinue)) {
        Write-Warning "certutil not found, skipping certificate import"
        return
    }

    # Install certificates
    if (Test-Path $RootCertPublicPEMFile) {
        Write-Host "Importing root certificate ${RootCertPublicPEMFile}..."
        certutil -f -user -addstore "My" $RootCertPublicPEMFile
    } else {
        Write-Warning "Certificate $RootCertPublicPEMFile does not exist, have you run 'terraform apply' yet?"
        return
    }
    if (Test-Path $ClientCertMergedPEMFile) {
        $clientCertMergedPFXFile = ($ClientCertMergedPEMFile -replace ".pem", ".pfx")
        Write-Verbose "Creating ${clientCertMergedPFXFile} from ${ClientCertMergedPEMFile}..."
        certutil -f -user -mergepfx -p "${CertPassword},${CertPassword}" $ClientCertPublicPEMFile $clientCertMergedPFXFile
        #openssl pkcs12 -in $ClientCertPublicPEMFile -inkey ($ClientCertPublicPEMFile replace ".pem",".key") -certfile $RootCertPublicPEMFile -out $clientCertMergedPFXFile -export -password 'pass:$CertPassword'
        Write-Host "Importing ${clientCertMergedPFXFile}..."
        certutil -f -user -importpfx -p $CertPassword "My" $clientCertMergedPFXFile
    } else {
        Write-Warning "Certificate $ClientCertMergedPEMFile does not exist, have you run 'terraform apply' yet?"
        return
    }
}

function Install-ClassicWindowsClient (
    [parameter(Mandatory=$true)][string]$PackagePath
) {
    if ([environment]::Is64BitOperatingSystem) {
        $vpnPackage = (Join-Path $PackagePath WindowsAmd64 VpnClientSetupAmd64.exe)
    } else {
        $vpnPackage = (Join-Path $PackagePath WindowsX86 VpnClientSetupX86.exe)
    }
    if (!(Test-Path $vpnPackage)) {
        Write-Error "Package $vpnPackage not found"
    }

    $vpnPackage
}

function Invoke (
    [string]$cmd
) {
    Write-Host "`n$cmd" -ForegroundColor Green 
    Invoke-Expression $cmd
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Warning "'$cmd' exited with status $exitCode"
        exit $exitCode
    }
}

function Update-AzureVPNProfile (
    [parameter(Mandatory=$true)][string]$PackagePath,
    [parameter(Mandatory=$false)][string]$ClientCert,
    [parameter(Mandatory=$false)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer,
    [parameter(Mandatory=$true)][string]$ProfileName,
    [parameter(Mandatory=$false)][switch]$Install
) {
    Write-Host "`nConfiguring Azure VPN profile..."

    $profileFileName = Join-Path $PackagePath AzureVPN azurevpnconfig.xml
    if (!(Test-Path $profileFileName)) {
        Write-Error "$ProfileFileName not found"
        return
    }
    Write-Verbose "Azure VPN Profile ${ProfileFileName}"

    # Edit VPN Profile
    Write-Host "Modifying VPN profile DNS configuration..."
    $vpnProfileXml = [xml](Get-Content $profileFileName)
    $clientconfig = $vpnProfileXml.SelectSingleNode("//*[name()='clientconfig']")
    $dnsserversNode = $vpnProfileXml.CreateElement("dnsservers", $vpnProfileXml.AzVpnProfile.xmlns)
    $dnsserverNode = $vpnProfileXml.CreateElement("dnsserver", $vpnProfileXml.AzVpnProfile.xmlns)
    $dnsserverNode.InnerText = $dnsServer
    $dnsserversNode.AppendChild($dnsserverNode) | Out-Null
    $clientconfig.AppendChild($dnsserversNode) | Out-Null
    $clientconfig.RemoveAttribute("nil","http://www.w3.org/2001/XMLSchema-instance")

    Copy-Item $profileFileName "${profileFileName}.backup"
    $vpnProfileXml.Save($profileFileName)

    if ($Install) {
        if (!$IsWindows) {
            Write-Warning "$($PSVersionTable.Platform) does not support Azure VPN profiles"
            return
        }

        if (Get-Command azurevpn -ErrorAction SilentlyContinue) {
            $vpnProfileDirectory = "$env:userprofile\AppData\Local\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe\LocalState"
            $vpnProfileFile = (Join-Path $vpnProfileDirectory "${ProfileName}.xml")
            Copy-Item $profileFileName $vpnProfileFile
            Write-Host "Azure VPN app importing profile '$vpnProfileFile'..."
            Push-Location $vpnProfileDirectory
            azurevpn -f -i (Split-Path $vpnProfileFile -Leaf)
            Pop-Location
        } else {
            Write-Host "Use the Azure VPN app (https://go.microsoft.com/fwlink/?linkid=2117554) to import this profile:`n${profileFileName}"
        }
    }
}

function Update-GenericVPNProfile (
    [parameter(Mandatory=$true)][string]$PackagePath,
    [parameter(Mandatory=$false)][string]$ClientCert,
    [parameter(Mandatory=$false)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer
) {
    Write-Host "`nConfiguring generic VPN profile..."

    $genericProfileDirectory = Join-Path $PackagePath Generic
    $profileFileName = Join-Path $genericProfileDirectory VpnSettings.xml
    if (!(Test-Path $profileFileName)) {
        Write-Error "$profileFileName not found"
        return
    }
    Write-Verbose "Generic Profile is ${ProfileFileName}"

    $genericProfileXml = [xml](Get-Content $profileFileName)

    # Locate DNS Server setting
    $dnsServersNode = $genericProfileXml.SelectSingleNode("//*[name()='CustomDnsServers']")
    $dnsServersNode.InnerText = $dnsServer

    # Locate VPN Server setting
    $vpnServersNode = $genericProfileXml.SelectSingleNode("//*[name()='VpnServer']")
    Write-Host "VPN Server is $($vpnServersNode.InnerText)"

    Copy-Item $profileFileName "${profileFileName}.backup"
    $genericProfileXml.Save($profileFileName)

    if ($IsMacOS) {
        security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain $genericProfileDirectory/VpnServerRoot.cer
    }
}

function Update-OpenVPNProfile (
    [parameter(Mandatory=$true)][string]$PackagePath,
    [parameter(Mandatory=$true)][string]$ClientCert,
    [parameter(Mandatory=$true)][string]$ClientKey,
    [parameter(Mandatory=$true)][string]$DnsServer
) {
    Write-Host "`nConfiguring OpenVPN profile..."

    $profileFileName = Join-Path $tempPackagePath OpenVPN vpnconfig.ovpn
    if (!(Test-Path $profileFileName)) {
        Write-Error "$profileFileName not found"
        return
    }
    Write-Verbose "OpenVPN Profile is ${profileFileName}"
    Copy-Item $ProfileFileName "${profileFileName}.backup"

    (Get-Content $profileFileName) -replace '\$CLIENTCERTIFICATE',($ClientCert -replace "$","`n") | Out-File $profileFileName
    (Get-Content $profileFileName) -replace '\$PRIVATEKEY',($ClientKey -replace "$","`n")         | Out-File $profileFileName

    # Add DNS
    Write-Output "`ndhcp-option DNS ${DnsServer}`n" | Out-File $profileFileName -Append

    Write-Debug "OpenVPN Profile:`n$(Get-Content $profileFileName -Raw)"
}