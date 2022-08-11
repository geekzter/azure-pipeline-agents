#!/usr/bin/env pwsh
<#
.SYNOPSIS 
    Lists image releases
 
.DESCRIPTION 
    Downloads latest image releases from https://github.com/repos/actions/runner-images
#> 

(Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner-images/releases") | ForEach-Object {
    $_ | Add-Member -NotePropertyName Image   -NotePropertyValue $_.tag_name.Split("/")[0]
    $_ | Add-Member -NotePropertyName Preview -NotePropertyValue (($_.draft -ieq "true") -or ($_.prerelease -ieq "true"))
    $_ | Add-Member -NotePropertyName Version -NotePropertyValue $_.tag_name.Split("/")[1]
    $_ | Add-Member -NotePropertyName Commit  -NotePropertyValue $_.target_commitish
    $_
} | Select-Object -Property Name, id, Image, Version, Preview, Commit | Format-Table