# Static checks for the Chart Cue scripts (no REAPER needed). Run before deploying:
#   .\tools\check.ps1
# 1. Syntax (luac -p)                       - must pass
# 2. Undefined globals (from the luac listing) - must pass
# 3. Lua Language Server warnings            - information only (many are false alarms:
#    it cannot see that a value is checked earlier in the same function)
# These checks find syntax errors and wrong names. They do not replace a test in REAPER.

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$failed = $false

# luac.exe: on the PATH, else the winget install folder
$luac = (Get-Command luac -ErrorAction SilentlyContinue).Source
if (-not $luac) { $luac = Join-Path $env:LOCALAPPDATA "Programs\Lua\bin\luac.exe" }
if (-not (Test-Path $luac)) { Write-Host "luac.exe not found. Install Lua 5.4: winget install DEVCOM.Lua" -ForegroundColor Red; exit 2 }

# globals that are allowed: standard Lua and REAPER
$known = @('reaper', 'string', 'math', 'table', 'utf8', 'io', 'os', 'package', 'ipairs', 'pairs',
  'tostring', 'tonumber', 'type', 'pcall', 'xpcall', 'setmetatable', 'getmetatable', 'dofile',
  'next', 'select', 'error', 'print', 'assert', 'rawget', 'rawset', 'require', '_G')

$files = @("Chart Cue", "Segue", "MIDI Pilot") | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path $_ } |
  ForEach-Object { Get-ChildItem -Path $_ -Filter "*.lua" }
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
  # each script folder; the warnings come from the JSON file of the tool (its screen format changes between versions)
  foreach ($dir in @("Chart Cue", "Segue", "MIDI Pilot")) {
    $src = Join-Path $root $dir
    if (-not (Test-Path $src)) { continue }
    $json = Join-Path $log "result.json"
    Remove-Item $json -ErrorAction SilentlyContinue
    & $exe --check $src --checklevel=Warning --configpath="$root\.luarc.json" --logpath=$log --check_out_path=$json 2>&1 | Out-Null
    $warn = @()
    if (Test-Path $json) {
      $res = Get-Content $json -Raw | ConvertFrom-Json
      $props = if ($res -is [array]) { @() } else { $res.PSObject.Properties } # [] = no warnings
      foreach ($f in $props) {
        $name = [uri]::UnescapeDataString(($f.Name -split '/')[-1])
        foreach ($d in $f.Value) { $warn += "${name}:$($d.range.start.line + 1) [$($d.code)] $(($d.message -split "`n")[0])" }
      }
    } else { Write-Host "  $dir`: the Language Server wrote no result" -ForegroundColor Red }
    $warn | Sort-Object | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Write-Host "  ${dir}: $($warn.Count) warning(s). Check new ones; most 'Need check nil' warnings are false alarms."
  }
} else {
  Write-Host "  skipped (VS Code extension 'Lua' by sumneko not found)"
}

if ($failed) { Write-Host "`nCHECKS FAILED" -ForegroundColor Red; exit 1 }
Write-Host "`nSyntax and globals OK" -ForegroundColor Green
exit 0 # (the Language Server's own exit code is information only)
