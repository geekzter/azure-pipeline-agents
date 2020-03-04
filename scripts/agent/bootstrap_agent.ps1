Write-Host "Hello World"

#Set-PSDebug -Trace 2

$customData = "$($env:SYSTEMDRIVE)\AzureData\CustomData.bin"

if (Test-Path $customData) {
    $config = Get-Content $customData | ConvertFrom-Json
    $config
} else {
    Write-Error "$customData not found"
    exit 1
}

Write-Host "Downloading Windows bootstrap script..."
Invoke-Webrequest https://raw.githubusercontent.com/geekzter/bootstrap-os/master/windows/bootstrap_windows.ps1 -OutFile $env:TEMP\bootstrap_windows.ps1 -UseBasicParsing
Write-Host "Executing Windows bootstrap script..."
& $env:TEMP\bootstrap_windows.ps1 -PowerShell $true

Write-Host "Downloading Windows agent install script..."
Invoke-Webrequest $config.agentscripturl-OutFile $env:TEMP\install_agent.ps1 -UseBasicParsing
Write-Host "Executing Windows agent install script..."
& $env:TEMP\install_agent.ps1 -AgentName $config.agentname -AgentPool $config.agentpool -Organization $config.organization -PAT $config.pat
