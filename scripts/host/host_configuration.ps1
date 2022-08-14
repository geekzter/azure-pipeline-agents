if (!$IsWindows -and ($PSVersionTable.PSEdition -ine "Desktop")) {
    Write-Error "This only runs on Windows..."
    exit 1
}

# Run post generation, of available on image
if (Test-Path C:\post-generation) {
    # https://github.com/actions/runner-images/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
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
if (![string]::IsNullOrEmpty("${smb_share}")) {
    if (!(Get-Command New-SmbGlobalMapping -ErrorAction SilentlyContinue)) {
        Write-Warning "Command 'New-SmbGlobalMapping' not found. Agent diagnostics will be stored locally."
        exit 0
    }

    Test-NetConnection -ComputerName ${storage_share_host} -Port 445 | Set-Variable connectResult
    if (!$connectResult.TcpTestSucceeded) {
        Write-Error -Message "Unable to reach '${storage_share_host}' via port 445."
    }

    $agentUser = "AzDevOps"
    if (!(Get-LocalUser $agentUser -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name "$agentUser" -Description "Pre-created by $($MyInvocation.MyCommand.Name)" -NoPassword -AccountNeverExpires
    }

    # BUG: 'New-SmbGlobalMapping -Persistent $true' is not persistent
    # ConvertTo-SecureString -String "${storage_account_key}" -AsPlainText -Force | Set-Variable storageKey
    # New-Object System.Management.Automation.PSCredential -ArgumentList "AZURE\${storage_account_name}", $storageKey | Set-Variable credential 
    # New-SmbGlobalMapping -RemotePath "${smb_share}" -Credential $credential -LocalPath ${drive_letter}: -FullAccess @( "NT AUTHORITY\SYSTEM", "NT AUTHORITY\NETWORK SERVICE", "${user_name}" ) -Persistent $true -RequirePrivacy $true #-UseWriteThrough

    # FIX: Use classic command-line tools instead
    cmd.exe /C "cmdkey /add:`"${smb_fqdn}`" /user:`"AZURE\${storage_account_name}`" /pass:`"${storage_account_key}`""
    net use ${drive_letter}: ${smb_share} /global /persistent:yes /user:AZURE\${storage_account_name} "${storage_account_key}"
    dir ${drive_letter}:

    # Link agent diagnostics directory
    "{0}:\{1}\{2}" -f "${drive_letter}", (Get-Date -Format 'yyyy\\MM\\dd'), $env:COMPUTERNAME | Set-Variable diagnosticsSMBDirectory
    New-Item -ItemType directory -Path $diagnosticsSMBDirectory -Force
    if (!(Test-Path $diagnosticsSMBDirectory)) {
        "'{0}' not found, has share {1} been mounted on {2}:?" -f $diagnosticsSMBDirectory, "${smb_share}", "${drive_letter}" | Write-Error
    }
    New-Item -ItemType symboliclink -Path "${diagnostics_directory}" -Value "$diagnosticsSMBDirectory" -Force

    $syncScript = "${drive_letter}:\\sync_windows_vm_logs.cmd"
    if (!(Test-Path $syncScript)) {
        Write-Error -Message "Unable to find '$syncScript'"
        exit 0
    }
    Unblock-File -Path $syncScript
    schtasks.exe /create /f /i 1 /ru "NT AUTHORITY\SYSTEM" /sc onidle /tn "Sync logs to file share" /tr $syncScript
}