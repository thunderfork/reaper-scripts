# Copies the scripts to REAPER (the ReaPack folder when installed with ReaPack, else Scripts\ or Scripts\<name>).
#   .\tools\deploy.ps1          (quiet: 1 summary line)
#   .\tools\deploy.ps1 -Full    (1 line per file)
param([switch]$Full)
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$srcdir = Join-Path $root "Chart Cue"
$scripts = Join-Path $env:APPDATA "REAPER\Scripts" # the standard REAPER resource folder of this Windows user
$done = @()
# installed with ReaPack: the actions run the copy in the ReaPack folder, so deploy there
# ("Thunderfork Scripts" = the ReaPack repository name)
foreach ($name in "Thunderfork Scripts") {
  $reapack = Join-Path $scripts "$name\Chart Cue"
  if (Test-Path $reapack) { $scripts = $reapack; break }
}

# Chart Cue.lua and the small action scripts (next / previous page, performance mode)
$n = 0
Get-ChildItem -Path $srcdir -Filter "Chart Cue*.lua" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $scripts $_.Name) -Force
    if ($Full) { Write-Host "Deployed $($_.Name) to $scripts" }
    $n++
}
$done += "Chart Cue ($n)"

# Segue, MIDI Pilot and FX Link: the ReaPack folder when installed with ReaPack, else Scripts\<name>
foreach ($s in "Segue", "MIDI Pilot", "FX Link") {
  $setsrc = Join-Path $root $s
  if (-not (Test-Path $setsrc)) { continue }
  $base = Join-Path $env:APPDATA "REAPER\Scripts"
  $dest = Join-Path $base $s
  foreach ($name in "Thunderfork Scripts") {
    $rp = Join-Path $base "$name\$s"
    if (Test-Path $rp) { $dest = $rp; break }
  }
  New-Item -ItemType Directory -Force $dest | Out-Null
  $n = 0
  Get-ChildItem -Path $setsrc -Filter "$s*.lua" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dest $_.Name) -Force
    if ($Full) { Write-Host "Deployed $($_.Name) to $dest" }
    $n++
  }
  $done += "$s ($n)"
}
Write-Host ("Deployed: " + ($done -join ", ") + " file(s)")
