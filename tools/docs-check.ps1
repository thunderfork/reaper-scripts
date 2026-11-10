# Checks that the documents still match the repository (run by check.ps1; also on its own):
#   .\tools\docs-check.ps1
# In CLAUDE.md, the folder CLAUDE.md files, README.md, PLAN.md and the skills:
# 1. paths in backticks (tools\..., tests\..., "MIDI Pilot/...", .claude\...) that no longer exist;
# 2. skill names (`name` skill) that do not exist in .claude\skills;
# 3. "Settings > Section" paths whose section is in no script, and "Settings > Section > Name" paths whose name is
#    in no script. A line that shows a rename ("->") is skipped.
# Prints 1 line when everything matches; else each problem (information only: it never fails the checks).
$root = Split-Path $PSScriptRoot -Parent
$docs = @("CLAUDE.md", "README.md", "PLAN.md", "Chart Cue\CLAUDE.md", "Segue\CLAUDE.md", "MIDI Pilot\CLAUDE.md") |
  ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path $_ }
$docs += Get-ChildItem (Join-Path $root ".claude\skills") -Recurse -Filter "SKILL.md" | ForEach-Object { $_.FullName }
$skills = Get-ChildItem (Join-Path $root ".claude\skills") -Directory | ForEach-Object { $_.Name }
$code = @("Chart Cue\Chart Cue.lua", "Segue\Segue.lua", "MIDI Pilot\MIDI Pilot.lua") |
  ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path $_ } | ForEach-Object { Get-Content $_ -Raw }
$allCode = $code -join "`n"
# the Settings section names of the scripts (SETTINGS_SECTIONS = { { "Viewer", ... }, ... })
$sections = @()
foreach ($c in $code) {
  $m = [regex]::Match($c, 'SETTINGS_SECTIONS\s*=\s*\{(.*?)\n\}', 'Singleline')
  if ($m.Success) { $sections += [regex]::Matches($m.Groups[1].Value, '\{\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } }
}
$tops = @("tools", "tests", "Chart Cue", "Segue", "MIDI Pilot", "FX Link", ".claude", ".github")
$problems = @()
foreach ($doc in $docs) {
  $rel = $doc.Substring($root.Length + 1)
  $n = 0
  foreach ($line in (Get-Content $doc)) {
    $n++
    if ($line -match '->') { continue } # (a rename: old -> new)
    # 1. paths in backticks
    foreach ($m in [regex]::Matches($line, '`([^`]+)`')) {
      $p = $m.Groups[1].Value -replace '^\.\\', '' -replace '^\./', ''
      if ($p -match '[<>*%$]' -or $p -match '^[A-Za-z]:' -or $p -match '\s-[A-Za-z]' -or $p -match '^(git|gh|python|luac) ') { continue }
      $first = ($p -split '[\\/]')[0]
      if (($p -match '[\\/]') -and ($tops -contains $first) -and ($p -match '\.(lua|ps1|md|json|txt|yml)$')) {
        if (-not (Test-Path (Join-Path $root $p))) { $problems += "${rel}:$n path not found: $p" }
      }
    }
    # 2. skill names
    foreach ($m in [regex]::Matches($line, '`([a-z][a-z-]+)` skill')) {
      if ($skills -notcontains $m.Groups[1].Value) { $problems += "${rel}:$n no such skill: $($m.Groups[1].Value)" }
    }
    # 3. Settings paths
    foreach ($m in [regex]::Matches($line, 'Settings > ([A-Z][A-Za-z]+)(?: > ([A-Z][A-Za-z'' ]*[A-Za-z]))?')) {
      $sec = $m.Groups[1].Value
      if ($sections -notcontains $sec) { $problems += "${rel}:$n no Settings section '$sec'" }
      elseif ($m.Groups[2].Success -and -not $allCode.Contains($m.Groups[2].Value)) {
        $problems += "${rel}:$n '$($m.Groups[2].Value)' (Settings > $sec) is in no script"
      }
    }
  }
}
if ($problems.Count -eq 0) { Write-Host "Docs OK ($($docs.Count) files)"; exit 0 }
Write-Host "Docs: $($problems.Count) problem(s):" -ForegroundColor Yellow
$problems | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
exit 0
