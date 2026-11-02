$srcdir = Join-Path $PSScriptRoot "Chart Cue"
$scripts = Join-Path $env:APPDATA "REAPER\Scripts" # the standard REAPER resource folder of this Windows user

# Chart Cue.lua and the small action scripts (next / previous page, performance mode)
Get-ChildItem -Path $srcdir -Filter "Chart Cue*.lua" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $scripts $_.Name) -Force
    Write-Host "Deployed $($_.Name) to REAPER Scripts."
}
