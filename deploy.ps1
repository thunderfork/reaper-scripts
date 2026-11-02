$src = Join-Path $PSScriptRoot "Chart Cue.lua"
$dst = "C:\Users\ngkog\AppData\Roaming\REAPER\Scripts\Chart Cue.lua"

Copy-Item $src $dst -Force
Write-Host "Deployed Chart Cue.lua to REAPER Scripts."

# the small action scripts (next / previous page, performance mode), next to Chart Cue.lua
$scripts = Split-Path $dst
Get-ChildItem -Path $PSScriptRoot -Filter "Chart Cue - *.lua" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $scripts $_.Name) -Force
    Write-Host "Deployed $($_.Name) to REAPER Scripts."
}
