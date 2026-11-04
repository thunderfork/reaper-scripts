# UI test: runs tools\ui-test.lua in the portable test REAPER (C:\REAPERtest, never the normal REAPER).
# It opens every tab, Settings section, menu and page area and lists the errors that Chart Cue wrote.
# The test REAPER window must be visible (a minimised window stops ReaImGui): it takes the focus for
# about 1 minute. Ask the user first.
$repo = Split-Path -Parent $PSScriptRoot
$script = Join-Path $PSScriptRoot "ui-test.lua"
$log = "$env:TEMP\chartcue_menutest.txt"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process "C:\REAPERtest\reaper.exe" -ArgumentList "-newinst", "-nosplash", "`"$script`"" -PassThru
if (-not $p.WaitForExit(180000)) { $p.Kill(); Write-Host "UI TEST TIMEOUT" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $log)) { Write-Host "No log: the UI test did not run." -ForegroundColor Red; exit 1 }
# (case-sensitive: each "step:" line also says "(error before: nil)")
$bad = Select-String -Path $log -CaseSensitive -Pattern "STEP ERROR|TRACE|CONSOLE|error before: [^n]"
$steps = (Select-String -Path $log -Pattern "^step: ").Count
if ($bad) { $bad | ForEach-Object { $_.Line }; Write-Host "UI test: $steps steps, errors found" -ForegroundColor Red; exit 1 }
if (Select-String -Path $log -Pattern "^DONE") { Write-Host "UI test: $steps steps, no errors" -ForegroundColor Green }
else { Write-Host "UI test: stopped after $steps steps" -ForegroundColor Red; exit 1 }
