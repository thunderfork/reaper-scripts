# Static checks for the scripts (no REAPER needed). Run before deploying:
#   .\tools\check.ps1               (quiet: 1 summary line; details only on a failure or a new warning)
#   .\tools\check.ps1 -Full         (every file and every warning)
#   .\tools\check.ps1 -All          (all scripts; without it: only the scripts with a file changed since the last
#                                    commit, or all when a file in tools\ or .luarc.json changed)
#   .\tools\check.ps1 -UpdateKnown  (the current warnings become the known ones: tools\known-warnings.txt; all scripts)
#   .\tools\check.ps1 -Force        (run even when the same files passed already: tools\stamp.ps1)
# 1. Syntax (luac -p)                       - must pass
# 2. Undefined globals (from the luac listing) - must pass; 2b. CFG names read but never set - must pass
# 3. Lua Language Server warnings            - information only (many are false alarms: it cannot see that a value
#    is checked earlier in the same function). Compared with tools\known-warnings.txt by file, code and text (not by
#    line: the lines move with every change); only a new one is shown.
# These checks find syntax errors and wrong names. They do not replace a test in REAPER.
param([switch]$Full, [switch]$UpdateKnown, [switch]$All, [switch]$Force)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$knownFile = Join-Path $PSScriptRoot "known-warnings.txt"
$failed = $false
function Say($text, $color) { if ($Full) { if ($color) { Write-Host $text -ForegroundColor $color } else { Write-Host $text } } }

# luac.exe: on the PATH, else the winget install folder
$luac = (Get-Command luac -ErrorAction SilentlyContinue).Source
if (-not $luac) { $luac = Join-Path $env:LOCALAPPDATA "Programs\Lua\bin\luac.exe" }
if (-not (Test-Path $luac)) { Write-Host "luac.exe not found. Install Lua 5.4: winget install DEVCOM.Lua" -ForegroundColor Red; exit 2 }

# globals that are allowed: standard Lua and REAPER
$known = @('reaper', 'string', 'math', 'table', 'utf8', 'io', 'os', 'package', 'coroutine', 'debug', 'ipairs', 'pairs',
  'tostring', 'tonumber', 'type', 'pcall', 'xpcall', 'setmetatable', 'getmetatable', 'dofile',
  'next', 'select', 'error', 'print', 'assert', 'rawget', 'rawset', 'require', '_G')

$scriptList = @((Import-PowerShellDataFile (Join-Path $PSScriptRoot "scripts.psd1")).Scripts) # tools\scripts.psd1
# the scripts to check: the changed ones (a file in its folder or one of its Uses files, staged, not staged or new)
$changed = @(@(git -C $root diff --name-only HEAD) + @(git -C $root ls-files --others --exclude-standard) | Where-Object { $_ })
if ($LASTEXITCODE -ne 0) { $All = $true } # (git could not tell what changed)
$scriptNames = @($scriptList | Where-Object {
    $s = $_
    $All -or $UpdateKnown -or ($changed | Where-Object {
        $_ -like "tools/*" -or $_ -eq ".luarc.json" -or $_ -like "$($s.Name)/*" -or ($s.Uses -and ($s.Uses -replace '\\', '/') -contains $_)
      })
  } | ForEach-Object { $_.Name })
$scope = if ($scriptNames.Count -eq $scriptList.Count) { "all scripts" } else { "$($scriptNames.Count) of $($scriptList.Count) scripts (changed; -All for all)" }
# the same files passed already (tools\stamp.ps1): only the fast checks of the files that the stamp does not cover
. (Join-Path $PSScriptRoot "stamp.ps1")
$stampName = if ($scriptNames.Count -eq $scriptList.Count) { "check-all" } else { "check" }
if (-not ($Force -or $Full -or $UpdateKnown) -and (Test-Passed $stampName)) {
  & (Join-Path $PSScriptRoot "docs-check.ps1")
  & (Join-Path $PSScriptRoot "publish-check.ps1") | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host "  Publish check failed: a push stops until this is fixed" -ForegroundColor Yellow }
  Write-Host "Syntax and globals: passed already on these files, $scope (-Force to run again)" -ForegroundColor Green
  exit 0
}
$files = $scriptNames | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path $_ } |
  ForEach-Object { Get-ChildItem -Path $_ -Filter "*.lua" }
Say "== 1. Syntax ==" Cyan
foreach ($f in $files) {
  $out = & $luac -p $f.FullName 2>&1
  if ($LASTEXITCODE -eq 0) { Say "  OK    $($f.Name)" }
  else { Write-Host "  FAIL  syntax: $($f.Name)`n        $out" -ForegroundColor Red; $failed = $true }
}

Say "== 2. Undefined globals ==" Cyan
foreach ($f in $files) {
  $list = & $luac -l -l -p $f.FullName 2>&1
  $names = $list | Select-String '(GETTABUP|SETTABUP)\s.*_ENV\s+"([^"]+)"' |
    ForEach-Object { $_.Matches[0].Groups[2].Value } | Sort-Object -Unique
  $bad = $names | Where-Object { $known -notcontains $_ }
  if ($bad) { Write-Host "  FAIL  globals: $($f.Name): $($bad -join ', ')" -ForegroundColor Red; $failed = $true }
  else { Say "  OK    $($f.Name)" }
}

# 2b. Every CFG.NAME that a file reads is defined in it ("CFG.NAME =", or a key of its "CFG = { ... }" block): a
# constant that was removed or moved but is still read gives nil only when that code runs (lessons 23 November 2026:
# Note Detective's Tempo and bars window read CFG.BPM_MIN after the move to Tempo.lua). Comments are skipped; the
# CFG of another table (TP.CFG.NAME) is not the file's.
Say "== 2b. Undefined CFG names ==" Cyan
foreach ($f in $files) {
  $code = (Get-Content $f.FullName) | ForEach-Object { $_ -replace '--.*$', '' }
  $text = $code -join "`n"
  $defs = @{}
  foreach ($m in [regex]::Matches($text, '(?<![\w.])CFG\.([A-Z][A-Z_0-9]*)(?=(\s*,\s*CFG\.[A-Z][A-Z_0-9]*)*\s*=[^=])')) { $defs[$m.Groups[1].Value] = $true }
  foreach ($b in [regex]::Matches($text, '(?s)CFG\s*=\s*\{(.*?)\n\}')) {
    foreach ($m in [regex]::Matches($b.Groups[1].Value, '\b([A-Z][A-Z_0-9]*)\s*=[^=]')) { $defs[$m.Groups[1].Value] = $true }
  }
  $bad = [regex]::Matches($text, '(?<![\w.])CFG\.([A-Z][A-Z_0-9]*)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique |
    Where-Object { -not $defs[$_] }
  if ($bad) { Write-Host "  FAIL  CFG: $($f.Name): $(($bad | ForEach-Object { 'CFG.' + $_ }) -join ', ') read but never set" -ForegroundColor Red; $failed = $true }
  else { Say "  OK    $($f.Name)" }
}

Say "== 3. Lua Language Server (information only) ==" Cyan
$summary = @()
$warnings = @() # every warning: "file [code] text" (no line), for the comparison
$shown = @()    # with the line, for the screen
$ls = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter "sumneko.lua-*" -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending | Select-Object -First 1
$exe = if ($ls) { Join-Path $ls.FullName "server\bin\lua-language-server.exe" } else { $null }
if ($exe -and (Test-Path $exe)) {
  $log = Join-Path $env:TEMP "chartcue_luals"
  New-Item -ItemType Directory -Force $log | Out-Null
  # each script folder; the warnings come from the JSON file of the tool (its screen format changes between versions)
  foreach ($dir in $scriptNames) {
    $src = Join-Path $root $dir
    if (-not (Test-Path $src)) { continue }
    $json = Join-Path $log "result.json"
    Remove-Item $json -ErrorAction SilentlyContinue
    & $exe --check $src --checklevel=Warning --configpath="$root\.luarc.json" --logpath=$log --check_out_path=$json 2>&1 | Out-Null
    $n = 0
    if (Test-Path $json) {
      $res = Get-Content $json -Raw | ConvertFrom-Json
      $props = if ($res -is [array]) { @() } else { $res.PSObject.Properties } # [] = no warnings
      foreach ($f in $props) {
        $name = [uri]::UnescapeDataString(($f.Name -split '/')[-1])
        foreach ($d in $f.Value) {
          $text = ($d.message -split "`n")[0]
          $warnings += "$name [$($d.code)] $text"
          $shown += [pscustomobject]@{ key = "$name [$($d.code)] $text"; line = "${name}:$($d.range.start.line + 1) [$($d.code)] $text" }
          $n++
        }
      }
    } else { Write-Host "  $dir`: the Language Server wrote no result" -ForegroundColor Red }
    $summary += "$dir $n"
  }
  $shown | Sort-Object line | ForEach-Object { Say "  $($_.line)" Yellow }
} else {
  Write-Host "  Language Server skipped (VS Code extension 'Lua' by sumneko not found)"
}

# the known warnings: a new one is one more of its kind (file, code, text) than the known ones
if ($UpdateKnown) {
  # (UTF-8 without a byte-order mark, LF line ends: Set-Content -Encoding utf8 writes a BOM in PowerShell 5.1)
  [System.IO.File]::WriteAllText($knownFile, ((@($warnings | Sort-Object) -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "Known warnings saved: $($warnings.Count) in tools\known-warnings.txt"
}
$knownCount = @{}
if (Test-Path $knownFile) { Get-Content $knownFile | Where-Object { $_ -ne "" } | ForEach-Object { $knownCount[$_] = 1 + [int]$knownCount[$_] } }
$nowCount = @{}
foreach ($k in $warnings) { $nowCount[$k] = 1 + [int]$nowCount[$k] }
$new = @()
foreach ($k in $nowCount.Keys) { if ($nowCount[$k] -gt [int]$knownCount[$k]) { $new += $k } }
if ($new.Count -gt 0) {
  Write-Host "NEW Language Server warning(s) (look at each; if it is a false alarm: .\tools\check.ps1 -UpdateKnown):" -ForegroundColor Yellow
  $shown | Where-Object { $new -contains $_.key } | Sort-Object line | ForEach-Object { Write-Host "  $($_.line)" -ForegroundColor Yellow }
}

# 4. the documents match the repository (information only; 1 line when they do)
& (Join-Path $PSScriptRoot "docs-check.ps1")
# the ImGui Push / Pop balance per function (information only; 1 line when nothing is new)
& (Join-Path $PSScriptRoot "imgui-check.ps1")
# 5. the publish check (information here; the pre-push hook stops a push when it fails)
& (Join-Path $PSScriptRoot "publish-check.ps1") | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "  (a push stops until this is fixed: release the script or hide it)" -ForegroundColor Yellow }

if ($failed) { Write-Host "CHECKS FAILED" -ForegroundColor Red; exit 1 }
$w = if ($summary.Count) { "; warnings: " + ($summary -join ", ") + $(if ($new.Count) { " ($($new.Count) new)" } else { " (none new)" }) } else { "" }
Write-Host "Syntax and globals OK, $scope$w" -ForegroundColor Green
Save-Stamp "check" # (no 2nd check of the same files: here and in the pre-commit hook)
if ($stampName -eq "check-all") { Save-Stamp "check-all" }
exit 0 # (the Language Server's own exit code is information only)
