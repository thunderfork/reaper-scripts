# The copy check (run by check.ps1; a difference fails the checks):
#   .\tools\copy-check.ps1   (1 line when all copies are the same; else each function and the scripts that differ)
# Small helpers that are copied into several scripts (no shared file: each script works alone) must stay the same
# text in every script that has them. The source is the first script in tools\scripts.psd1 that has the function.
# A change to 1 copy: make it in every copy. A helper that must differ in 1 script: remove it from $names.
$names = @("UI.push_style", "UI.pop_style", "UI.pre_begin", "UI.trunc", "UI.trunc_c", "UI.notice_h", "UI.toggle_line",
  "Util.write_all", "Util.fmt_mmss", "Util.playing")
$root = Split-Path $PSScriptRoot -Parent
$list = (Import-PowerShellDataFile (Join-Path $PSScriptRoot "scripts.psd1")).Scripts

# the text of a top-level function: from its "function" line to the first line that starts with "end"
function Get-FunctionText([string[]]$src, [string]$name) {
  $start = '^(local )?function ' + [regex]::Escape($name) + '\('
  for ($i = 0; $i -lt $src.Count; $i++) {
    if ($src[$i] -match $start) {
      for ($j = $i + 1; $j -lt $src.Count; $j++) { if ($src[$j] -match '^end') { return ($src[$i..$j] -join "`n") } }
    }
  }
  return $null
}

$texts = @{} # name -> list of { script, text }
foreach ($n in $names) { $texts[$n] = @() }
foreach ($s in $list) {
  $file = Join-Path $root "$($s.Name)\$($s.Name).lua"
  if (-not (Test-Path $file)) { continue }
  $src = Get-Content $file -Encoding utf8
  foreach ($n in $names) {
    $t = Get-FunctionText $src $n
    if ($t) { $texts[$n] += [pscustomobject]@{ script = $s.Name; text = $t } }
  }
}
$bad = @(); $copies = 0
foreach ($n in $names) {
  $all = $texts[$n]
  if ($all.Count -lt 2) { continue }
  $copies += $all.Count
  $diff = @($all | Select-Object -Skip 1 | Where-Object { $_.text -ne $all[0].text } | ForEach-Object { $_.script })
  if ($diff.Count) { $bad += "  $n`: $($diff -join ', ') not the same as in $($all[0].script)" }
}
if ($bad.Count) {
  Write-Host "COPIES DIFFER (make every copy the same, or remove the name from tools\copy-check.ps1):" -ForegroundColor Red
  $bad | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  exit 1
}
Write-Host "Copies OK ($($names.Count) helpers, $copies copies)"
exit 0
