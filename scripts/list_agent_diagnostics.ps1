#Requires -Version 7

param ( 
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE ?? "default"
) 

. (Join-Path $PSScriptRoot functions.ps1)

Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath data -AdditionalChildPath $Workspace,agent,diagnostics | Set-Variable diagnosticsPath
Write-Debug $diagnosticsPath

if (!(Test-Path $diagnosticsPath)) {
    "Diagnostics path {0} not found. Run download_agent_diagnostics.ps1 first." -f $diagnosticsPath | Write-Warning
    exit
}

Get-ChildItem -Path $diagnosticsPath -Recurse -File | Where-Object {$_.Directory.Name -ne "pages"} `
                                                    | ForEach-Object {
    $_ | Add-Member -NotePropertyName DiagnosticsType -NotePropertyValue ($_.Name -replace "[_|-].*$", "")
    $_ | Add-Member -NotePropertyName OS -NotePropertyValue ($_.DirectoryName -match "linux" ? "Linux" : ($_.DirectoryName -match "windows" ? "Windows" : "Unknown"))
    $_
} | Group-Object -Property OS, DiagnosticsType | Select-Object -Property Name, Count | ForEach-Object {
    $_ | Add-Member -NotePropertyName OS -NotePropertyValue $_.Name.Split(", ")[0]
    $_ | Add-Member -NotePropertyName DiagnosticsType -NotePropertyValue $_.Name.Split(", ")[1]
    $_
} | Select-Object -Property OS, DiagnosticsType, Count
