if (!$IsWindows -and ($PSVersionTable.PSEdition -ine "Desktop")) {
    Write-Error "This only runs on Windows..."
    exit 1
}

if (!(Test-Path X:\)) {
    Write-Host "File share not mounted"
    exit 0
}

$diagnosticsSMBDirectory = "X:\$(Get-Date -Format 'yyyy\\MM\\dd')\${env:COMPUTERNAME}\azure"
New-Item -ItemType directory -Path $diagnosticsSMBDirectory -Force -ErrorAction SilentlyContinue

robocopy C:\WindowsAzure\Logs $diagnosticsSMBDirectory *.log /fp /s /v /xo
