# Makes the zips for direct sharing (the GitHub Releases): release\<Name>-<version>.zip
# (the scripts of the folder, README.md and LICENSE). Run the checks first:
#   .\tools\check.ps1; .\tools\release.ps1 -Script "Chart Cue"
# -Script "Chart Cue", "Segue", "MIDI Pilot" or "FX Link": only the scripts that get a new version (default: all)
param([string[]]$Script = @("Chart Cue", "Segue", "MIDI Pilot", "FX Link"))
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$out = Join-Path $root "release"
New-Item -ItemType Directory -Force $out | Out-Null

foreach ($name in $Script) {
  $src = Join-Path $root $name
  $main = Join-Path $src "$name.lua"
  if (-not (Test-Path $main)) { Write-Host "No $name.lua" -ForegroundColor Red; exit 1 }
  # the version from the script header (@version), so the zip name always matches
  $line = Select-String -Path $main -Pattern '^-- @version\s+(\S+)' | Select-Object -First 1
  if (-not $line) { Write-Host "No @version in $name.lua" -ForegroundColor Red; exit 1 }
  $ver = $line.Matches[0].Groups[1].Value

  $stage = Join-Path $out "$name $ver"
  if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
  New-Item -ItemType Directory -Force $stage | Out-Null
  Copy-Item (Join-Path $src "*.lua") $stage
  Copy-Item (Join-Path $root "README.md"), (Join-Path $root "LICENSE") $stage

  $zip = Join-Path $out ("{0}-{1}.zip" -f ($name -replace ' ', '-'), $ver)
  if (Test-Path $zip) { Remove-Item -Force $zip }
  Compress-Archive -Path $stage -DestinationPath $zip
  Remove-Item -Recurse -Force $stage
  Write-Host "Made $zip" -ForegroundColor Green
}
