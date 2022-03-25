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
    $connectTestResult = Test-NetConnection -ComputerName ${storage_share_host} -Port 445
    if (!$connectTestResult.TcpTestSucceeded) {
        Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
    }

    # cmd.exe /c "cmdkey /add:`"${storage_share_host}`" /user:`"localhost\${storage_account_name}`" /pass:`"${storage_account_key}`""
    ConvertTo-SecureString -String "${storage_account_key}" -AsPlainText -Force | Set-Variable storageKey
    New-Object System.Management.Automation.PSCredential -ArgumentList "AZURE\${storage_account_name}", $storageKey | Set-Variable credential 
    New-PSDrive -Credential $credential -Name ${drive_letter} -PSProvider FileSystem -Root "${smb_share}" -Persist -Scope global

    # Link agent diagnostics directory
    Join-Path ${drive_letter}:\ $env:COMPUTERNAME | Set-Variable diagnosticsSMBDirectory
    New-Item -ItemType directory -Path $diagnosticsSMBDirectory -Force
    if (!(Test-Path $diagnosticsSMBDirectory)) {
        "'{0}' not found, has share {1} been mounted on {2}:?" -f $diagnosticsSMBDirectory, "${smb_share}", "${drive_letter}"  | Write-Error
    }
    # New-Item -ItemType symboliclink -Path "${diagnostics_directory}" -Value "$diagnosticsSMBDirectory" -Force
}