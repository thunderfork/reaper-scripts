$src = Join-Path $PSScriptRoot "Chart Cue.lua"
$dst = "C:\Users\ngkog\AppData\Roaming\REAPER\Scripts\Chart Cue.lua"

Copy-Item $src $dst -Force
Write-Host "Deployed Chart Cue.lua to REAPER Scripts."