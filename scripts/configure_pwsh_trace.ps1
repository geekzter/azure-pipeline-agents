#!/usr/bin/env pwsh

if ($env:SYSTEM_DEBUG -eq "true") {
    Set-PSDebug -Trace 2

    $InformationPreference = "Continue"
    $VerbosePreference = "Continue"
    $DebugPreference = "Continue"

    $env:PACKER_LOG = 1
    $env:TF_LOG     = "DEBUG"
}