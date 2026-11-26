# Runs the logic tests in the portable test REAPER (C:\REAPERtest), not in your normal REAPER:
#   .\tools\test.ps1
# The test file of each script (tools\scripts.psd1, e.g. tests\run.lua for Chart Cue): for each, the test REAPER opens,
# runs the tests, writes the result file and closes.
# -Script "<name>" (a name from tools\scripts.psd1): run only the tests of the changed script (default: all)
# Quiet by default: the failed tests and 1 summary line per script. -Full: every test line.
# -Coverage: also which functions of the script the tests ran (a call hook; slower). 1 line per script, and the
#   functions never run in tests\coverage_<test file>.txt (git-ignored).
# A script whose tests passed already on the same files is skipped (tools\stamp.ps1); -Force runs it.
param([string[]]$Script = @(), [switch]$Full, [switch]$Coverage, [switch]$Force)
$list = (Import-PowerShellDataFile (Join-Path $PSScriptRoot "scripts.psd1")).Scripts
if (-not $Script.Count) { $Script = @($list | ForEach-Object { $_.Name }) }
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$reaper = "C:\REAPERtest\reaper.exe"
if (-not (Test-Path $reaper)) { Write-Host "Test REAPER not found: $reaper" -ForegroundColor Red; exit 2 }
. (Join-Path $PSScriptRoot "background.ps1") # in the background: your window keeps the focus
. (Join-Path $PSScriptRoot "stamp.ps1") # (a pass: Save-Stamp; Test-Passed: no 2nd run on the same files)

$bad = $false
$all = @($list | ForEach-Object { , @($_.Name, $_.Test, $_.Result) })
foreach ($n in $Script) { if (-not ($list | Where-Object { $_.Name -eq $n })) { Write-Host "Unknown script: $n (tools\scripts.psd1)" -ForegroundColor Red; exit 2 } }
foreach ($s in $all) {
  if ($Script -notcontains $s[0]) { continue }
  if (-not ($Force -or $Full -or $Coverage) -and (Test-Passed "test-$($s[0])")) {
    Write-Host "$($s[0]): passed already on these files (-Force to run again)"; continue
  }
  $t = @($s[1], $s[2])
  $result = Join-Path $root "tests\$($t[1])"
  Remove-Item $result -ErrorAction SilentlyContinue
  $run = Join-Path $root "tests\$($t[0])"
  # a syntax error in the test file: say so here, not as a ReaScript error window in the test REAPER
  $luacp = (Get-Command luac -ErrorAction SilentlyContinue).Source
  if (-not $luacp) { $luacp = Join-Path $env:LOCALAPPDATA "Programs\Lua\bin\luac.exe" }
  if (Test-Path $luacp) {
    $syn = & $luacp -p $run 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Host "$($s[0]): syntax error in tests\$($t[0]): $syn" -ForegroundColor Red; $bad = $true; continue }
  }
  if ($Coverage) {
    # a wrapper in tests\ (the tests find their folder from the started script): a call hook notes the first line
    # of each function of the script that runs; written just before the tests quit REAPER (action 40004)
    $hits = Join-Path $env:TEMP "tf_cov_hits.txt"
    Remove-Item $hits -ErrorAction SilentlyContinue
    $wrap = Join-Path $root "tests\_cov_$($t[0])"
    $lua = @"
-- @noindex
local target, out, match = [[$run]], [[$hits]], [[\$($s[0]).lua]]
local hits = {}
debug.sethook(function()
  local i = debug.getinfo(2, "S")
  if i and i.source:sub(-#match) == match then hits[i.linedefined] = true end
end, "c")
local quit = reaper.Main_OnCommand
reaper.Main_OnCommand = function(c, f)
  if c == 40004 then
    debug.sethook()
    local h = io.open(out, "w")
    if h then for k in pairs(hits) do h:write(k, "\n") end h:close() end
  end
  return quit(c, f)
end
dofile(target)
"@
    [System.IO.File]::WriteAllText($wrap, $lua, (New-Object System.Text.UTF8Encoding($false)))
    $run = $wrap
  }
  $p = Start-BackgroundReaper $reaper @("-newinst", "-nosplash", "`"$run`"")
  if (-not $p) { Write-Host "Could not start the test REAPER." -ForegroundColor Red; exit 2 }
  if (-not (Wait-BackgroundReaper $p 120)) { $p.Kill(); Write-Host "Timeout: the test REAPER did not close." -ForegroundColor Red }
  if (-not (Test-Path $result)) { Write-Host "No tests\$($t[1]): the tests did not run." -ForegroundColor Red; $bad = $true; continue }
  $text = Get-Content $result
  foreach ($line in $text) {
    if ($line -like "FAIL*") { Write-Host $line -ForegroundColor Red }
    elseif ($Full -or $line -match "passed, \d+ failed") { Write-Host $(if ($line -match "passed, \d+ failed") { "$($s[0]): $line" } else { $line }) }
  }
  if ($text -match "^FAIL") { $bad = $true }
  elseif (-not $Coverage -and ($text -match "passed, 0 failed")) { Save-Stamp "test-$($s[0])" }
  if ($Coverage) {
    Remove-Item $wrap -ErrorAction SilentlyContinue
    if (-not (Test-Path $hits)) { Write-Host "$($s[0]): no coverage data (the tests did not reach their end)" -ForegroundColor Yellow; continue }
    $seen = @{}; Get-Content $hits | ForEach-Object { $seen[[int]$_] = $true }
    $luac = (Get-Command luac -ErrorAction SilentlyContinue).Source
    if (-not $luac) { $luac = Join-Path $env:LOCALAPPDATA "Programs\Lua\bin\luac.exe" }
    $main = Join-Path $root "$($s[0])\$($s[0]).lua"
    $src = Get-Content $main
    # every function of the script: its first line (luac -l: "function <file:first,last>")
    $firsts = & $luac -l -p $main | Select-String '^function <.*:(\d+),\d+>' | ForEach-Object { [int]$_.Matches[0].Groups[1].Value } | Sort-Object -Unique
    $never = @()
    foreach ($l in $firsts) {
      if ($seen[$l]) { continue }
      $code = $src[$l - 1]
      $m = [regex]::Match($code, 'function\s+([\w\.:]+)\s*\(')
      if (-not $m.Success) { $m = [regex]::Match($code, '([\w\.\[\]"]+)\s*=\s*function') }
      $never += if ($m.Success) { "${l}: $($m.Groups[1].Value)" } else { "${l}: (anonymous) $($code.Trim())" }
    }
    $total = $firsts.Count; $run_n = $total - $never.Count
    $pct = if ($total) { [math]::Round(100 * $run_n / $total) } else { 0 }
    $report = Join-Path $root ("tests\coverage_" + ($t[0] -replace '\.lua$', '.txt'))
    $head = "$($s[0]): $run_n of $total functions run by the tests ($pct%). Never run (line: name):"
    [System.IO.File]::WriteAllText($report, ((@($head) + $never) -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "$($s[0]): coverage $run_n / $total functions ($pct%) - never run: tests\$(Split-Path $report -Leaf)"
  }
}
if ($bad) { exit 1 }
