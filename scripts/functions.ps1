# Distributed Tasks requires 7.1
# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/?view=azure-devops-rest-7.1
$apiVersion="7.1-preview.1"

function Create-RequestHeaders(
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token=($env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN ?? $env:SYSTEM_ACCESSTOKEN)
)
{
    $base64AuthInfo = [Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes(":${Token}"))
    $authHeader = "Basic $base64AuthInfo"
    Write-Debug "Authorization: $authHeader"
    $requestHeaders = @{
        Accept = "application/json"
        Authorization = $authHeader
        "Content-Type" = "application/json"
    }

    return $requestHeaders
}

function Get-Pool(
    [parameter(Mandatory=$true)][string]$OrganizationUrl,

    [parameter(Mandatory=$true)][int[]]$PoolId,

    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token=$env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN ?? $env:SYSTEM_ACCESSTOKEN
)
{
    $poolIdString = ($PoolId -join ",")
    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/pools?poolIds=${poolIdString}&api-version=${apiVersion}"
    Write-Verbose "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -Token $Token
    try {
        Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Get | Set-Variable pools
    } catch {
        Write-RestError
        exit 1
    }

    if (($DebugPreference -ine "SilentlyContinue") -and $pools.value) {
        $pools.value | Write-Debug
    }
    return $pools
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

function Get-ScaleSetPools(
    [parameter(Mandatory=$true)][string]$OrganizationUrl,

    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token=$env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN ?? $env:SYSTEM_ACCESSTOKEN
)
{
    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/elasticpools?api-version=${apiVersion}"
    Write-Verbose "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -Token $Token
    try {
        Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Get | Set-Variable scaleSets
    } catch {
        Write-RestError
        exit 1
    }
    
    if (($DebugPreference -ine "SilentlyContinue") -and $scaleSets.value) {
        $scaleSets.value | Write-Debug
    }
    return $scaleSets
}

function Invoke (
    [string]$cmd
) {
    Write-Host "`n$cmd" -ForegroundColor Green 
    Invoke-Expression $cmd
    Validate-ExitCode $cmd
}

function Login-Az (
    [parameter(Mandatory=$false)][switch]$DisplayMessages=$false
) {
    # Are we logged in? If so, is it the right tenant?
    $azureAccount = $null
    az account show 2>$null | ConvertFrom-Json | Set-Variable azureAccount
    if ($azureAccount -and "${env:ARM_TENANT_ID}" -and ($azureAccount.tenantId -ine $env:ARM_TENANT_ID)) {
        Write-Warning "Logged into tenant $($azureAccount.tenant_id) instead of $env:ARM_TENANT_ID (`$env:ARM_TENANT_ID)"
        $azureAccount = $null
    }
    if (-not $azureAccount) {
        if ($env:CODESPACES -ieq "true") {
            $azLoginSwitches = "--use-device-code"
        }
        if ($env:ARM_TENANT_ID) {
            az login -t $env:ARM_TENANT_ID -o none $($azLoginSwitches)
        } else {
            az login -o none $($azLoginSwitches)
        }
    }

    if ($env:ARM_SUBSCRIPTION_ID) {
        az account set -s $env:ARM_SUBSCRIPTION_ID -o none
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

function Login-AzDO (
    [parameter(Mandatory=$false)][string]$OrganizationUrl=($env:AZDO_ORG_SERVICE_URL ?? $env:SYSTEM_COLLECTIONURI),
    [parameter(Mandatory=$false)][switch]$DisplayMessages=$false
)
{
    Login-Az -DisplayMessages:$DisplayMessages

    $resource="499b84ac-1321-427f-aa17-267ca6975798"
    az account get-access-token --resource $resource `
                                --query "accessToken" `
                                --output tsv `
                                | Set-Variable aadToken
    if ($aadToken) {
        Write-Debug "Obtained AAD token with 'az account get-access-token'"
        az account show -o json | ConvertFrom-Json | Set-Variable account
        if ($account.user.type -eq 'user') {
            # Assume Terraform azuredevops module will use Entra ID AuthN directly for non-users
            $env:AZDO_PERSONAL_ACCESS_TOKEN = $aadToken # Terraform azuredevops provider
            $env:TF_VAR_devops_pat = $aadToken # Terraform azuredevops provider
        }
        $env:AZURE_DEVOPS_EXT_PAT = $aadToken # Azure DevOps CLI azuredevops extension
    } else {
        Write-Error "Unable to get AAD token"
    }

    if (!(az extension list --query "[?name=='azure-devops'].version" -o tsv)) {
        Write-Host "Adding Azure CLI extension 'azure-devops'..."
        az extension add -n azure-devops -y
    }
    if ($DisplayMessages) {
        Write-Verbose "Using Azure DevOps organization '$OrganizationUrl'"
        $aadToken | az devops login --organization $OrganizationUrl
        az devops configure --defaults organization="$OrganizationUrl"
    }
}

function Set-PipelineVariablesFromTerraform () {
    $json = terraform output -json | ConvertFrom-Json -AsHashtable
    foreach ($outputVariable in $json.keys) {
        $value = $json[$outputVariable].value
        if ($value) {
            if ($value -notmatch "`n") {
                $sensitive = $json[$outputVariable].sensitive.ToString().ToLower()
                # Write variable output in the format a Pipeline can understand
                "##vso[task.setvariable variable={0};isOutput=true;issecret={2}]{1}" -f $outputVariable, $value, $sensitive | Write-Host
            } else {
                Write-Verbose "Ignoring multi-line output variable '${outputVariable}'"
            }
        }
    }
}

function Validate-ExitCode (
    [string]$cmd
) {
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Warning "'$cmd' exited with status $exitCode"
        exit $exitCode
    }
}

function Write-RestError() {
    if ($_.ErrorDetails.Message) {
        try {
            $_.ErrorDetails.Message | ConvertFrom-Json | Set-Variable restError
            $restError | Format-List | Out-String | Write-Debug
            $message = $restError.message
        } catch {
            $message = $_.ErrorDetails.Message
        }
    } else {
        $message = $_.Exception.Message
    }
    Write-Warning $message
}