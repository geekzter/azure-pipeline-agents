#Requires -Version 7
<#
.SYNOPSIS 
    List or search log files

.DESCRIPTION 
    List or search log files downloaded with download_agent_diagnostics.ps1

.EXAMPLE
    ./list_agent_diagnostics.ps1

.EXAMPLE
    ./list_agent_diagnostics.ps1 MyEvent

#> 
param ( 
    [parameter(Mandatory=$false)][string]$Pattern,
    [parameter(Mandatory=$false)][switch]$AllMatches,
    [parameter(Mandatory=$false)][switch]$IncludeVMExtensionLogs,
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE ?? "default"
) 

. (Join-Path $PSScriptRoot functions.ps1)

Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath data -AdditionalChildPath $Workspace,agent,diagnostics | Set-Variable diagnosticsPath
Write-Debug $diagnosticsPath

if (!(Test-Path $diagnosticsPath)) {
    "Diagnostics path {0} not found. Run download_agent_diagnostics.ps1 first." -f $diagnosticsPath | Write-Warning
    exit
}

Get-ChildItem -Path $diagnosticsPath -Recurse -File | Set-Variable diagnosticsFiles

if (!$IncludeVMExtensionLogs) {
    $diagnosticsFiles | Where-Object {($_.Directory.Name -notin "azure","pages","Plugins") -and ($_.Directory.FullName -notmatch "Plugins/Microsoft")} `
                      | Set-Variable diagnosticsFiles
}

if ($Pattern) {
    # Search log files with given pattern
    $diagnosticsFiles | Select-String -Pattern $Pattern -List -AllMatches:$AllMatches
} else {
    # Provide summary by file type instead
    $diagnosticsFiles | ForEach-Object {
        $_ | Add-Member -NotePropertyName DiagnosticsType -NotePropertyValue ($_.Name -replace "[\.|\d|_|-].*$", "")
        $_ | Add-Member -NotePropertyName OS -NotePropertyValue ($_.DirectoryName -match "linux" ? "Linux" : ($_.DirectoryName -match "$([IO.Path]::DirectorySeparatorChar)win" ? "Windows" : "Unknown"))
        $_
    } | Where-Object {$_.DiagnosticsType -ine "sync"} `
      | Group-Object -Property OS, DiagnosticsType | Select-Object -Property Name, Count | ForEach-Object {
        $_ | Add-Member -NotePropertyName OS -NotePropertyValue $_.Name.Split(", ")[0]
        $_ | Add-Member -NotePropertyName DiagnosticsType -NotePropertyValue $_.Name.Split(", ")[1]
        $_
    } | Select-Object -Property OS, DiagnosticsType, Count
}
