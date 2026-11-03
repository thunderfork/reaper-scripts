$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$srcdir = Join-Path $root "Chart Cue"
$scripts = Join-Path $env:APPDATA "REAPER\Scripts" # the standard REAPER resource folder of this Windows user
# installed with ReaPack: the actions run the copy in the ReaPack folder, so deploy there
# ("Thunderfork Scripts" = the ReaPack repository name; "thunderfork" = its name before 3 November 2026)
foreach ($name in "Thunderfork Scripts", "thunderfork") {
  $reapack = Join-Path $scripts "$name\Chart Cue"
  if (Test-Path $reapack) { $scripts = $reapack; break }
}

# Chart Cue.lua and the small action scripts (next / previous page, performance mode)
Get-ChildItem -Path $srcdir -Filter "Chart Cue*.lua" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $scripts $_.Name) -Force
    Write-Host "Deployed $($_.Name) to $scripts"
}
