# Makes the zip for direct sharing: release\Chart-Cue-<version>.zip
# (the 4 scripts, README.md and LICENSE). Run the checks first:
#   .\tools\check.ps1; .\tools\release.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$src = Join-Path $root "Chart Cue"

# the version from the script header (@version), so the zip name always matches
$line = Select-String -Path (Join-Path $src "Chart Cue.lua") -Pattern '^-- @version\s+(\S+)' | Select-Object -First 1
if (-not $line) { Write-Host "No @version in Chart Cue.lua" -ForegroundColor Red; exit 1 }
$ver = $line.Matches[0].Groups[1].Value

$out = Join-Path $root "release"
$stage = Join-Path $out "Chart Cue $ver"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item (Join-Path $src "*.lua") $stage
Copy-Item (Join-Path $root "README.md"), (Join-Path $root "LICENSE") $stage

$zip = Join-Path $out "Chart-Cue-$ver.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $stage -DestinationPath $zip
Remove-Item -Recurse -Force $stage
Write-Host "Made $zip" -ForegroundColor Green
