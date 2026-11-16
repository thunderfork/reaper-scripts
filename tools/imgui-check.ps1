# The ImGui balance check (run by check.ps1; information only, it never fails the checks):
#   .\tools\imgui-check.ps1               (1 line when nothing new; else each new finding)
#   .\tools\imgui-check.ps1 -UpdateKnown  (the current findings become the known ones: tools\imgui-known.txt)
# In each function of each script (its own lines, not the functions inside it), the ImGui Push and Pop calls of each
# kind (StyleVar, StyleColor, ID, Font, ItemWidth, TextWrapPos) must add up to 0, and no "return" may come between
# a Push and its Pop. A Pop with a variable count (PopStyleColor(ctx, n)) cannot be counted: that kind is skipped
# in that function. A static count: a Push in an "if" or a loop can be a false alarm (then -UpdateKnown).
param([switch]$UpdateKnown)
$root = Split-Path $PSScriptRoot -Parent
$knownFile = Join-Path $PSScriptRoot "imgui-known.txt"
$luac = (Get-Command luac -ErrorAction SilentlyContinue).Source
if (-not $luac) { $luac = Join-Path $env:LOCALAPPDATA "Programs\Lua\bin\luac.exe" }
if (-not (Test-Path $luac)) { Write-Host "ImGui check skipped (no luac)"; exit 0 }
$kinds = "StyleVar", "StyleColor", "ID", "Font", "ItemWidth", "TextWrapPos"
$list = (Import-PowerShellDataFile (Join-Path $PSScriptRoot "scripts.psd1")).Scripts
$found = @(); $nf = 0
foreach ($s in $list) {
  $dir = Join-Path $root $s.Name
  if (-not (Test-Path $dir)) { continue }
  foreach ($file in (Get-ChildItem $dir -Filter "*.lua")) {
    $src = Get-Content $file.FullName
    if (-not ($src -match 'ImGui\.Push')) { continue }
    # the function ranges (luac -l), the largest first, so an inner function owns its lines
    $fns = & $luac -l -p $file.FullName | Select-String '^function <.*:(\d+),(\d+)>' |
      ForEach-Object { [pscustomobject]@{ a = [int]$_.Matches[0].Groups[1].Value; b = [int]$_.Matches[0].Groups[2].Value } } |
      Sort-Object { $_.b - $_.a } -Descending
    $owner = New-Object int[] ($src.Count + 2)
    $i = 0
    foreach ($f in $fns) { $i++; for ($l = $f.a; $l -le $f.b; $l++) { $owner[$l] = $i } }
    $nf += $fns.Count
    $i = 0
    foreach ($f in $fns) {
      $i++
      $bal = @{}; $skip = @{}; $open = 0; $ret = $null
      for ($l = $f.a; $l -le $f.b; $l++) {
        if ($owner[$l] -ne $i) { continue }
        # (texts in quotes out first: a tooltip can say "return"; then the comment)
        $code = $src[$l - 1] -replace '"(\\.|[^"\\])*"', '""' -replace "'(\\.|[^'\\])*'", "''" -replace '--.*$', ''
        # (a Push may have calls in its arguments: only its name is matched; a Pop's arguments are plain)
        foreach ($m in [regex]::Matches($code, 'ImGui\.(Push|Pop)(StyleVar|StyleColor|ID|Font|ItemWidth|TextWrapPos)\(([^()]*)')) {
          $k = $m.Groups[2].Value
          if ($m.Groups[1].Value -eq "Push") { $bal[$k] = 1 + [int]$bal[$k]; $open++ }
          else {
            $args_ = $m.Groups[3].Value -split ','
            $n = 1
            if ($k -in "StyleVar", "StyleColor" -and $args_.Count -ge 2) {
              $v = $args_[1].Trim()
              if ($v -match '^\d+$') { $n = [int]$v } else { $skip[$k] = $true; $n = 0; $open = 0 } # (pops all of that kind)
            }
            $bal[$k] = [int]$bal[$k] - $n; $open = [math]::Max(0, $open - [math]::Max($n, 1))
          }
        }
        if ($open -gt 0 -and -not $ret -and $code -match '(^|[^\w.])return\b') { $ret = $l }
      }
      $name = [regex]::Match($src[$f.a - 1], 'function\s+([\w\.:]+)\s*\(|([\w\.]+)\s*=\s*function')
      $fname = if ($name.Groups[1].Value) { $name.Groups[1].Value } elseif ($name.Groups[2].Value) { $name.Groups[2].Value } else { "(anonymous)" }
      foreach ($k in $kinds) {
        if ($skip[$k] -or -not $bal.ContainsKey($k) -or $bal[$k] -eq 0) { continue }
        $found += [pscustomobject]@{ key = "$($file.Name) $fname $k $($bal[$k])"; line = "$($file.Name):$($f.a) $fname`: $k Push - Pop = $($bal[$k])" }
      }
      if ($ret) { $found += [pscustomobject]@{ key = "$($file.Name) $fname return"; line = "$($file.Name):$ret $fname`: a return between a Push and its Pop" } }
    }
  }
}
if ($UpdateKnown) {
  [System.IO.File]::WriteAllText($knownFile, ((@($found | ForEach-Object { $_.key } | Sort-Object) -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "ImGui known findings saved: $($found.Count) in tools\imgui-known.txt"
}
$known = @{}
if (Test-Path $knownFile) { Get-Content $knownFile | Where-Object { $_ } | ForEach-Object { $known[$_] = $true } }
$new = @($found | Where-Object { -not $known[$_.key] })
if ($new.Count) {
  Write-Host "NEW ImGui balance finding(s) (look at each; a false alarm: .\tools\imgui-check.ps1 -UpdateKnown):" -ForegroundColor Yellow
  $new | ForEach-Object { Write-Host "  $($_.line)" -ForegroundColor Yellow }
} else { Write-Host "ImGui balance OK ($nf functions; $($found.Count) known)" }
exit 0
