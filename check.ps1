# Static checks for the Chart Cue scripts (no REAPER needed). Run before deploying:
#   .\check.ps1
# 1. Syntax (luac -p)                       - must pass
# 2. Undefined globals (from the luac listing) - must pass
# 3. Lua Language Server warnings            - information only (many are false alarms:
#    it cannot see that a value is checked earlier in the same function)
# These checks find syntax errors and wrong names. They do not replace a test in REAPER.

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$failed = $false

# luac.exe: on the PATH, else the winget install folder
$luac = (Get-Command luac -ErrorAction SilentlyContinue).Source
if (-not $luac) { $luac = Join-Path $env:LOCALAPPDATA "Programs\Lua\bin\luac.exe" }
if (-not (Test-Path $luac)) { Write-Host "luac.exe not found. Install Lua 5.4: winget install DEVCOM.Lua" -ForegroundColor Red; exit 2 }

# globals that are allowed: standard Lua and REAPER
$known = @('reaper', 'string', 'math', 'table', 'utf8', 'io', 'os', 'package', 'ipairs', 'pairs',
  'tostring', 'tonumber', 'type', 'pcall', 'xpcall', 'setmetatable', 'getmetatable', 'dofile',
  'next', 'select', 'error', 'print', 'assert', 'rawget', 'rawset', 'require', '_G')

$files = Get-ChildItem -Path $root -Filter "*.lua"
Write-Host "== 1. Syntax ==" -ForegroundColor Cyan
foreach ($f in $files) {
  $out = & $luac -p $f.FullName 2>&1
  if ($LASTEXITCODE -eq 0) { Write-Host "  OK    $($f.Name)" }
  else { Write-Host "  FAIL  $($f.Name)`n        $out" -ForegroundColor Red; $failed = $true }
}

Write-Host "== 2. Undefined globals ==" -ForegroundColor Cyan
foreach ($f in $files) {
  $list = & $luac -l -l -p $f.FullName 2>&1
  $names = $list | Select-String '(GETTABUP|SETTABUP)\s.*_ENV\s+"([^"]+)"' |
    ForEach-Object { $_.Matches[0].Groups[2].Value } | Sort-Object -Unique
  $bad = $names | Where-Object { $known -notcontains $_ }
  if ($bad) { Write-Host "  FAIL  $($f.Name): $($bad -join ', ')" -ForegroundColor Red; $failed = $true }
  else { Write-Host "  OK    $($f.Name)" }
}

Write-Host "== 3. Lua Language Server (information only) ==" -ForegroundColor Cyan
$ls = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter "sumneko.lua-*" -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending | Select-Object -First 1
$exe = if ($ls) { Join-Path $ls.FullName "server\bin\lua-language-server.exe" } else { $null }
if ($exe -and (Test-Path $exe)) {
  $log = Join-Path $env:TEMP "chartcue_luals"
  New-Item -ItemType Directory -Force $log | Out-Null
  $out = & $exe --check $root --checklevel=Warning --configpath="$root\.luarc.json" --logpath=$log --check_format=pretty 2>&1
  # one line per warning (the tool prints its list twice)
  $warn = $out | Select-String '^\S.*\.lua:\d+:\d+ \[' | ForEach-Object { $_.Line.Replace("$root\", "") } | Sort-Object -Unique
  if ($warn) { $warn | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow } } else { Write-Host "  no warnings" }
  Write-Host "  $(@($warn).Count) warning(s). Check new ones; most 'Need check nil' warnings are false alarms."
} else {
  Write-Host "  skipped (VS Code extension 'Lua' by sumneko not found)"
}

if ($failed) { Write-Host "`nCHECKS FAILED" -ForegroundColor Red; exit 1 }
Write-Host "`nSyntax and globals OK" -ForegroundColor Green
exit 0 # (the Language Server's own exit code is information only)
