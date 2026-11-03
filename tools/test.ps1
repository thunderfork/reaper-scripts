# Runs tests\run.lua in the portable test REAPER (C:\REAPERtest), not in your normal REAPER:
#   .\tools\test.ps1
# The test REAPER opens, runs the tests, writes tests\result.txt and closes.
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$reaper = "C:\REAPERtest\reaper.exe"
$result = Join-Path $root "tests\result.txt"
if (-not (Test-Path $reaper)) { Write-Host "Test REAPER not found: $reaper" -ForegroundColor Red; exit 2 }
Remove-Item $result -ErrorAction SilentlyContinue

$p = Start-Process $reaper -ArgumentList "-newinst", "-nosplash", "`"$(Join-Path $root 'tests\run.lua')`"" -PassThru
if (-not $p.WaitForExit(120000)) { $p.Kill(); Write-Host "Timeout: the test REAPER did not close." -ForegroundColor Red }

if (-not (Test-Path $result)) { Write-Host "No tests\result.txt: the tests did not run." -ForegroundColor Red; exit 1 }
$text = Get-Content $result
$text | ForEach-Object { if ($_ -like "FAIL*") { Write-Host $_ -ForegroundColor Red } else { Write-Host $_ } }
if ($text -match "^FAIL") { exit 1 }
