if (!$IsWindows -and ($PSVersionTable.PSEdition -ine "Desktop")) {
    Write-Error "This only runs on Windows..."
    exit 1
}

# Run post generation, of available on image
if (Test-Path C:\post-generation) {
    # https://github.com/actions/virtual-environments/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
    Get-ChildItem C:\post-generation -Filter *.ps1 | ForEach-Object { 
        if ($_.FullName -inotmatch "VSConfig|InternetExplorer") {
            Write-Host $_.FullName
            & $_.FullName 
        }
    }
}

%{ for name, value in environment }
    [Environment]::SetEnvironmentVariable("${name}", "${value}", "Machine")
%{ endfor ~}

# Mount file share
if ("${smb_share}") {
    if (!(Get-Command New-SmbGlobalMapping -ErrorAction SilentlyContinue)) {
        Write-Warning "Command 'New-SmbGlobalMapping' not found. Agent diagnostics will be stored locally."
        exit
    }

    Test-NetConnection -ComputerName ${storage_share_host} -Port 445 | Set-Variable connectResult
    if (!$connectResult.TcpTestSucceeded) {
        Write-Error -Message "Unable to reach '${storage_share_host}' via port 445."
    }

    $agentUser = "AzDevOps"
    if (!(Get-LocalUser $agentUser -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name "$agentUser" -Description "Pre-created by $($MyInvocation.MyCommand.Path)" -NoPassword -AccountNeverExpires
    }

    ConvertTo-SecureString -String "${storage_account_key}" -AsPlainText -Force | Set-Variable storageKey
    New-Object System.Management.Automation.PSCredential -ArgumentList "AZURE\${storage_account_name}", $storageKey | Set-Variable credential 
    New-SmbGlobalMapping -RemotePath "${smb_share}" -Credential $credential -LocalPath ${drive_letter}: -FullAccess @( "NT AUTHORITY\SYSTEM", $agentUser, "${user_name}" ) -Persistent $true #-UseWriteThrough

    # Link agent diagnostics directory
    Join-Path ${drive_letter}:\ $env:COMPUTERNAME | Set-Variable diagnosticsSMBDirectory
    New-Item -ItemType directory -Path $diagnosticsSMBDirectory -Force
    if (!(Test-Path $diagnosticsSMBDirectory)) {
        "'{0}' not found, has share {1} been mounted on {2}:?" -f $diagnosticsSMBDirectory, "${smb_share}", "${drive_letter}" | Write-Error
    }
    New-Item -ItemType symboliclink -Path "${diagnostics_directory}" -Value "$diagnosticsSMBDirectory" -Force
}