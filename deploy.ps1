$srcdir = Join-Path $PSScriptRoot "Chart Cue"
$scripts = "C:\Users\ngkog\AppData\Roaming\REAPER\Scripts"

# Chart Cue.lua and the small action scripts (next / previous page, performance mode)
Get-ChildItem -Path $srcdir -Filter "Chart Cue*.lua" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $scripts $_.Name) -Force
    Write-Host "Deployed $($_.Name) to REAPER Scripts."
}
