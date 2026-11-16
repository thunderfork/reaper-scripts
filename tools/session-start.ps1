# The state at the start of a Claude session (the SessionStart hook in .claude\settings.json; Claude reads it,
# the user does not see it). Also by hand: .\tools\session-start.ps1
# Prints: the branch, what is not committed or pushed, the unreleased scripts (tools\scripts.psd1), the open manual
# tests (PLAN.md "Open manual tests") and the newest PLAN.md handoff.
$root = Split-Path $PSScriptRoot -Parent
$out = @("State (session start)")

$branch = (& git -C $root rev-parse --abbrev-ref HEAD 2>$null)
$changed = @(& git -C $root status --porcelain 2>$null).Count
$ahead = (& git -C $root rev-list --count "@{u}..HEAD" 2>$null)
if (-not $ahead) { $ahead = "?" }
$out += "  Branch: $branch | Not committed: $changed file(s) | Not pushed: $ahead commit(s)"

$list = (Import-PowerShellDataFile (Join-Path $PSScriptRoot "scripts.psd1")).Scripts
$un = @()
foreach ($s in $list) {
  if ($s.Released) { continue }
  $main = Join-Path $root "$($s.Name)\$($s.Name).lua"
  $v = if (Test-Path $main) { (Select-String -Path $main -Pattern '^-- @version\s+(\S+)' | Select-Object -First 1).Matches[0].Groups[1].Value } else { "?" }
  $un += "$($s.Name) $v"
}
if ($un.Count) { $out += "  Unreleased: " + ($un -join ", ") }
& (Join-Path $PSScriptRoot "publish-check.ps1") *> $null
if ($LASTEXITCODE -ne 0) { $out += "  Publish check: FAILED (a push stops; run tools\publish-check.ps1)" }

# the cause tags of LESSONS.md: a tag with 2+ entries and no line in "Rules from lessons" needs a proposal
$lessons = Join-Path $root "LESSONS.md"
if (Test-Path $lessons) {
  $count = [ordered]@{}; $rules = ""; $inRules = $false
  foreach ($l in (Get-Content $lessons)) {
    if ($l -match '^## ') { $inRules = ($l -match '^## Rules from lessons'); continue }
    if ($inRules) { $rules += "$l`n" }
    $m = [regex]::Match($l, '^\d{4}-\d{2}-\d{2} \|[^|]*\|\s*([a-z-]+)\s*\|')
    if ($m.Success) { $t = $m.Groups[1].Value; $count[$t] = 1 + [int]$count[$t] }
  }
  if ($count.Count) {
    $out += "  Lesson tags: " + (($count.Keys | ForEach-Object { "$_ $($count[$_])" }) -join ", ")
    foreach ($t in $count.Keys) {
      if ($count[$t] -ge 2 -and $rules -notmatch "\b$([regex]::Escape($t))\b") {
        $out += "  -> $t has $($count[$t]) entries: propose a stronger fix (lessons skill, step 4)"
      }
    }
  }
}

$plan = Join-Path $root "PLAN.md"
if (Test-Path $plan) {
  $lines = Get-Content $plan
  # the open manual tests: the "- " lines of the section, before its "On hold" line
  $sec = $false; $open = 0; $hold = 0; $inHold = $false
  foreach ($l in $lines) {
    if ($l -match '^## ') { $sec = ($l -match '^## Open manual tests'); $inHold = $false; continue }
    if (-not $sec) { continue }
    if ($l -match '^On hold') { $inHold = $true; continue }
    if ($l -match '^- ') { if ($inHold) { $hold++ } else { $open++ } }
  }
  $out += "  Open manual tests: $open; on hold: $hold (PLAN.md)"
  # the newest handoff: the first "## Session handoff" section
  $h = $false; $hand = @()
  foreach ($l in $lines) {
    if ($l -match '^## Session handoff') { if ($h) { break }; $h = $true; $hand += "  $l"; continue }
    if ($h) { if ($l -match '^## ') { break }; if ($l.Trim()) { $hand += "  $l" } }
  }
  $out += $hand
}
$out -join "`n"
