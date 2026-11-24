# Copies the changed scripts to REAPER (the ReaPack folder when installed with ReaPack, else Scripts\ or
# Scripts\<name>): only the files that differ from the copy there.
#   .\tools\deploy.ps1          (quiet: 1 summary line)
#   .\tools\deploy.ps1 -Full    (1 line per file)
param([switch]$Full)
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$srcdir = Join-Path $root "Chart Cue"
$scripts = Join-Path $env:APPDATA "REAPER\Scripts" # the standard REAPER resource folder of this Windows user
$done = @()
# Copies 1 file only when the copy in REAPER is missing or different (unchanged scripts stay as they are).
# Returns 1 when it copied, else 0.
function Copy-Changed($src, $dst) {
  if ((Test-Path $dst) -and (Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) { return 0 }
  Copy-Item $src $dst -Force
  if ($Full) { Write-Host "Deployed $src to $dst" }
  return 1
}
# installed with ReaPack: the actions run the copy in the ReaPack folder, so deploy there
# ("Thunderfork Scripts" = the ReaPack repository name)
foreach ($name in "Thunderfork Scripts") {
  $reapack = Join-Path $scripts "$name\Chart Cue"
  if (Test-Path $reapack) { $scripts = $reapack; break }
}

# Chart Cue.lua and the small action scripts (next / previous page, performance mode)
$n = 0
Get-ChildItem -Path $srcdir -Filter "Chart Cue*.lua" | ForEach-Object {
    $n += Copy-Changed $_.FullName (Join-Path $scripts $_.Name)
}
if ($n -gt 0) { $done += "Chart Cue ($n)" }

# the other scripts (tools\scripts.psd1): the ReaPack folder when installed with ReaPack, else Scripts\<name>
foreach ($entry in ((Import-PowerShellDataFile (Join-Path $PSScriptRoot "scripts.psd1")).Scripts | Where-Object { $_.Name -ne "Chart Cue" })) {
  $s = $entry.Name
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
    $n += Copy-Changed $_.FullName (Join-Path $dest $_.Name)
  }
  foreach ($u in @($entry.Uses)) { # the shared files it needs next to it (tools\scripts.psd1: Uses)
    if (-not $u) { continue }
    $n += Copy-Changed (Join-Path $root $u) (Join-Path $dest (Split-Path $u -Leaf))
  }
  if ($n -gt 0) { $done += "$s ($n)" }
}
if ($done.Count -eq 0) { Write-Host "Deployed: nothing changed" }
else { Write-Host ("Deployed: " + ($done -join ", ") + " file(s)") }
