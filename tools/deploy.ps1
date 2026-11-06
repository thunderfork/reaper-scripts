$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$srcdir = Join-Path $root "Chart Cue"
$scripts = Join-Path $env:APPDATA "REAPER\Scripts" # the standard REAPER resource folder of this Windows user
# installed with ReaPack: the actions run the copy in the ReaPack folder, so deploy there
# ("Thunderfork Scripts" = the ReaPack repository name)
foreach ($name in "Thunderfork Scripts") {
  $reapack = Join-Path $scripts "$name\Chart Cue"
  if (Test-Path $reapack) { $scripts = $reapack; break }
}

# Chart Cue.lua and the small action scripts (next / previous page, performance mode)
Get-ChildItem -Path $srcdir -Filter "Chart Cue*.lua" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $scripts $_.Name) -Force
    Write-Host "Deployed $($_.Name) to $scripts"
}

# Segue and MIDI Pilot: the ReaPack folder when installed with ReaPack, else Scripts\<name>
foreach ($s in "Segue", "MIDI Pilot") {
  $setsrc = Join-Path $root $s
  if (-not (Test-Path $setsrc)) { continue }
  $base = Join-Path $env:APPDATA "REAPER\Scripts"
  $dest = Join-Path $base $s
  foreach ($name in "Thunderfork Scripts") {
    $rp = Join-Path $base "$name\$s"
    if (Test-Path $rp) { $dest = $rp; break }
  }
  New-Item -ItemType Directory -Force $dest | Out-Null
  Get-ChildItem -Path $setsrc -Filter "$s*.lua" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dest $_.Name) -Force
    Write-Host "Deployed $($_.Name) to $dest"
  }
}
