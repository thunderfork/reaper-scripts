# The publish check: a script that is not released yet (Released = $false in tools\scripts.psd1) must not reach
# ReaPack or the README with a push.
#   .\tools\publish-check.ps1             (the files in the working folder)
#   .\tools\publish-check.ps1 -Ref HEAD   (the committed files: the pre-push hook, tools\hooks\pre-push)
# For each such script: every .lua file in its folder has "-- @noindex" in its header, and README.md describes it
# only inside <!-- --> (hidden). Prints 1 line when everything is safe; else each problem, and exit 1.
param([string]$Ref = "")
$root = Split-Path $PSScriptRoot -Parent
$list = (Import-PowerShellDataFile (Join-Path $PSScriptRoot "scripts.psd1")).Scripts

function Read-Text($rel) {
  if ($Ref) {
    $t = & git -C $root show "${Ref}:$($rel -replace '\\', '/')" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($t -join "`n")
  }
  $p = Join-Path $root $rel
  if (-not (Test-Path $p)) { return $null }
  return [System.IO.File]::ReadAllText($p)
}
function Lua-Files($name) {
  if ($Ref) {
    return @(& git -C $root ls-tree --name-only "${Ref}:$name/" 2>$null | Where-Object { $_ -like "*.lua" } |
      ForEach-Object { "$name/$_" })
  }
  $dir = Join-Path $root $name
  if (-not (Test-Path $dir)) { return @() }
  return @(Get-ChildItem $dir -Filter "*.lua" | ForEach-Object { "$name/$($_.Name)" })
}

$problems = @()
$readme = Read-Text "README.md"
$shown = if ($readme) { [regex]::Replace($readme, '<!--.*?-->', '', 'Singleline') } else { "" }
foreach ($s in $list) {
  if ($s.Released) { continue }
  foreach ($f in (Lua-Files $s.Name)) {
    $text = Read-Text $f
    $head = (($text -split "`n") | Select-Object -First 20) -join "`n"
    if ($head -notmatch '(?m)^--\s*@noindex') { $problems += "$($s.Name) is not released, but ReaPack would publish $f (no @noindex)" }
  }
  $n = [regex]::Escape($s.Name)
  if ($shown -match "(?m)^#+\s*$n\s*$" -or $shown -match "\*\*$n[:*]") {
    $problems += "$($s.Name) is not released, but README.md describes it (hide it inside <!-- -->)"
  }
}
if ($problems.Count) {
  $problems | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  Write-Host "PUBLISH CHECK FAILED: release the script (Released = `$true in tools\scripts.psd1) or hide it" -ForegroundColor Red
  exit 1
}
Write-Host "Publish check OK"
exit 0
