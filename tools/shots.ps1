# Takes screenshots of the Chart Cue window in the portable test REAPER (C:\REAPERtest):
#   .\tools\shots.ps1                (compact layout, into tests\shots)
#   .\tools\shots.ps1 -Comfortable   ("Comfortable layout" on, into tests\shots\comfortable)
# tests\shots.lua shows each scene and writes tests\shots\req.txt; this script saves
# <folder>\<scene>.png and deletes req.txt. The test REAPER starts with no Chart Cue settings.
param([switch]$Comfortable)
$root = Split-Path $PSScriptRoot -Parent # the repository folder (this script is in tools\)
$reaper = "C:\REAPERtest\reaper.exe"
$dir = Join-Path $root "tests\shots"
$req = Join-Path $dir "req.txt"
$env:CHARTCUE_COMFORT = if ($Comfortable) { "1" } else { "0" }
if ($Comfortable) { $dir = Join-Path $dir "comfortable" }
if (-not (Test-Path $reaper)) { Write-Host "Test REAPER not found: $reaper" -ForegroundColor Red; exit 2 }
New-Item -ItemType Directory -Force $dir | Out-Null
Get-ChildItem $dir -Filter "*.png" | Remove-Item
Remove-Item $req -ErrorAction SilentlyContinue
Remove-Item "C:\REAPERtest\Data\Chart Cue\settings.ini" -ErrorAction SilentlyContinue # a first start

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class Win {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
}
"@
[Win]::SetProcessDPIAware() | Out-Null

$p = Start-Process $reaper -ArgumentList "-newinst", "-nosplash", "`"$(Join-Path $root 'tests\shots.lua')`"" -PassThru
$end = (Get-Date).AddSeconds(120)
while (-not $p.HasExited -and (Get-Date) -lt $end) {
  if (Test-Path $req) {
    $name = (Get-Content $req -Raw).Trim()
    $h = [Win]::FindWindow("reaper_imgui_context", "Chart Cue")
    if ($h -ne [IntPtr]::Zero) {
      [Win]::SetForegroundWindow($h) | Out-Null
      Start-Sleep -Milliseconds 400
      $rc = New-Object Win+RECT
      [Win]::GetWindowRect($h, [ref]$rc) | Out-Null
      $bmp = New-Object System.Drawing.Bitmap ($rc.R - $rc.L), ($rc.B - $rc.T)
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.CopyFromScreen($rc.L, $rc.T, 0, 0, $bmp.Size)
      $bmp.Save((Join-Path $dir "$name.png")); $g.Dispose(); $bmp.Dispose()
      Write-Host "  $name.png"
    } else { Write-Host "  $name : Chart Cue window not found" -ForegroundColor Red }
    Remove-Item $req
  }
  Start-Sleep -Milliseconds 100
}
if (-not $p.HasExited) { $p.Kill(); Write-Host "Timeout: the test REAPER did not close." -ForegroundColor Red }
