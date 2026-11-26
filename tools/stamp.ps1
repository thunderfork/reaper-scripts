# The pass stamps (no 2nd run of the same checks): check.ps1 and test.ps1 note a fingerprint of the files they read
# after a pass; they skip a new run when the files still have that fingerprint (-Force runs it), and the pre-commit
# hook skips a run when the files to commit have it.
# The fingerprint: every .lua file of the repository and every file in tools\ (tracked or new, not ignored), each with
# its git blob hash (git hash-object: the same as git add makes). The stamps: in the .git folder (never committed).
#   . .\tools\stamp.ps1                                    (Save-Stamp "check" / "test-Tab Viewer")
#   .\tools\stamp.ps1 -Test "check"                         exit 0: the staged files passed (the hook)
param([string]$Test = "")

$stampRoot = Split-Path $PSScriptRoot -Parent

function Get-Fingerprint([switch]$Index) {
  $files = @(git -C $stampRoot ls-files --cached --others --exclude-standard -- '*.lua' 'tools/*' | Sort-Object)
  if (-not $files.Count) { return "" }
  if ($Index) { # (the staged version of each file; a file that is not staged: none)
    $staged = @{}
    git -C $stampRoot ls-files -s -- '*.lua' 'tools/*' | ForEach-Object {
      if ($_ -match '^\d+ ([0-9a-f]+) \d+\t(.+)$') { $staged[$Matches[2]] = $Matches[1] }
    }
    $lines = $files | ForEach-Object { "$_ $(if ($staged[$_]) { $staged[$_] } else { 'none' })" }
  } else {
    $hashes = @(git -C $stampRoot hash-object -- $files) # (as arguments: a pipe from PowerShell 5.1 adds a BOM)
    $lines = for ($i = 0; $i -lt $files.Count; $i++) { "$($files[$i]) $($hashes[$i])" }
  }
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n")))
  return -join ($bytes | ForEach-Object { $_.ToString("x2") })
}
function Get-StampPath([string]$name) {
  $gd = git -C $stampRoot rev-parse --absolute-git-dir
  return Join-Path $gd ("tf-pass-" + ($name -replace '[^\w-]', '_') + ".txt")
}
# After a pass of name ("check", "test-<script>"): the fingerprint of the files as they are now.
function Save-Stamp([string]$name) {
  try { Set-Content -Path (Get-StampPath $name) -Value (Get-Fingerprint) -Encoding ascii } catch { }
}
# True when name passed on the files as they are now (check.ps1 and test.ps1 then skip the run; -Force runs it).
function Test-Passed([string]$name) {
  try {
    $file = Get-StampPath $name
    if (-not (Test-Path $file)) { return $false }
    $saved = (Get-Content $file -Raw).Trim()
    return [bool]($saved -and $saved -eq (Get-Fingerprint))
  } catch { return $false }
}

if ($Test) {
  $file = Get-StampPath $Test
  if (-not (Test-Path $file)) { exit 1 }
  $saved = (Get-Content $file -Raw).Trim()
  if ($saved -and $saved -eq (Get-Fingerprint -Index)) { exit 0 }
  exit 1
}
