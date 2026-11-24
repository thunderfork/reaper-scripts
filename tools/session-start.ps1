# The state at the start of a Claude session (the SessionStart hook in .claude\settings.json; Claude reads it,
# the user does not see it). Also by hand: .\tools\session-start.ps1
# Prints: the branch, what is not committed or pushed, the unreleased scripts (tools\scripts.psd1), the lesson tags
# without a rule (LESSONS.md, LESSONS-RULES.md), the open items and manual tests (PLAN.md "Open now"), the age of
# the last checkup, and the PLAN.md handoff.
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

# the cause tags of LESSONS.md: a tag with 2+ entries and no line in LESSONS-RULES.md needs a proposal
$lessons = Join-Path $root "LESSONS.md"
$rulesFile = Join-Path $root "LESSONS-RULES.md"
if (Test-Path $lessons) {
  $count = [ordered]@{}
  $rules = if (Test-Path $rulesFile) { Get-Content $rulesFile -Raw } else { "" }
  foreach ($l in (Get-Content $lessons)) {
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
  $lines = Get-Content $plan -Encoding UTF8
  # "Open now": the numbered items; the manual tests start with "Manual test"
  $sec = $false; $open = 0; $tests = 0; $planned = $false; $per = [ordered]@{}
  foreach ($l in $lines) {
    if ($l -match '^## ') { $sec = ($l -match '^## Open now'); continue }
    if ($sec -and $l -match '^\d+\. ') {
      $open++
      if ($l -match '^\d+\. Manual test \(([^,)]+)') { $tests++; $per[$Matches[1]] = 1 + [int]$per[$Matches[1]] }
      if ($l -match '`checkup`') { $planned = $true }
    }
  }
  $out += "  Open now: $open item(s), $tests of them manual tests (PLAN.md)"
  foreach ($k in $per.Keys) {
    if ($per[$k] -gt 3) { $out += "  -> $k has $($per[$k]) open manual tests: no new feature in $k until they are tested" }
  }
  # the last checkup: "Last checkup: <day> <month> <year>" in the handoff; none or older than 30 days: a checkup
  $lc = $lines | Where-Object { $_ -match 'Last checkup:' } | Select-Object -First 1
  $m = [regex]::Match("$lc", 'Last checkup:\s*(\d{1,2} [A-Z][a-z]+ \d{4})')
  $d = [datetime]::MinValue
  if ($planned) { } # a checkup is already under Open now
  elseif ($m.Success -and [datetime]::TryParseExact($m.Groups[1].Value, 'd MMMM yyyy', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$d)) {
    $age = [int]((Get-Date) - $d).TotalDays
    if ($age -gt 30) { $out += "  -> last checkup $age days ago: put a checkup under Open now" }
  } elseif ($lc) { $out += "  -> no full checkup yet: put a checkup under Open now" }
  # the handoff: the "## Handoff" section
  $h = $false; $hand = @()
  foreach ($l in $lines) {
    if ($l -match '^## Handoff') { $h = $true; $hand += "  $l"; continue }
    if ($h) { if ($l -match '^## ') { break }; if ($l.Trim()) { $hand += "  $l" } }
  }
  $out += $hand
}
$out -join "`n"
