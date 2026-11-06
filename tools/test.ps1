# Runs the logic tests in the portable test REAPER (C:\REAPERtest), not in your normal REAPER:
#   .\tools\test.ps1
# tests\run.lua (Chart Cue), tests\segue.lua (Segue) and tests\midipilot.lua (MIDI Pilot): for each, the test REAPER opens, runs the
# tests, writes the result file and closes.
# -Script "Chart Cue", "Segue" or "MIDI Pilot": run only the tests of the changed script (default: all)
param([string[]]$Script = @("Chart Cue", "Segue", "MIDI Pilot"))
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$reaper = "C:\REAPERtest\reaper.exe"
if (-not (Test-Path $reaper)) { Write-Host "Test REAPER not found: $reaper" -ForegroundColor Red; exit 2 }
. (Join-Path $PSScriptRoot "background.ps1") # in the background: your window keeps the focus

$bad = $false
$all = @(@("Chart Cue", "run.lua", "result.txt"), @("Segue", "segue.lua", "result_segue.txt"), @("MIDI Pilot", "midipilot.lua", "result_midipilot.txt"))
foreach ($s in $all) {
  if ($Script -notcontains $s[0]) { continue }
  $t = @($s[1], $s[2])
  $result = Join-Path $root "tests\$($t[1])"
  Remove-Item $result -ErrorAction SilentlyContinue
  $p = Start-BackgroundReaper $reaper @("-newinst", "-nosplash", "`"$(Join-Path $root "tests\$($t[0])")`"")
  if (-not $p) { Write-Host "Could not start the test REAPER." -ForegroundColor Red; exit 2 }
  if (-not (Wait-BackgroundReaper $p 120)) { $p.Kill(); Write-Host "Timeout: the test REAPER did not close." -ForegroundColor Red }
  if (-not (Test-Path $result)) { Write-Host "No tests\$($t[1]): the tests did not run." -ForegroundColor Red; $bad = $true; continue }
  $text = Get-Content $result
  $text | ForEach-Object { if ($_ -like "FAIL*") { Write-Host $_ -ForegroundColor Red } else { Write-Host $_ } }
  if ($text -match "^FAIL") { $bad = $true }
}
if ($bad) { exit 1 }
