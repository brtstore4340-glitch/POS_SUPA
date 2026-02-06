# FILE: FIX_REVIEW_ONE_SHOT_NPMARGS.ps1
# PURPOSE: Patch REVIEW_ONE_SHOT.ps1 so Invoke-Cmd passes arguments correctly to npm (avoid "npm <command>" help).
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\FIX_REVIEW_ONE_SHOT_NPMARGS.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap { Write-Host ("[FATAL] " + $_.Exception.Message); exit 1 }

function New-Dir([string]$Path) { if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }
function Write-Utf8NoBom([string]$Path, [string]$Content) { $enc = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path, $Content, $enc) }
function Parse-Syntax([string]$FilePath) { $t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($FilePath,[ref]$t,[ref]$e); return $e }

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$toolsDir = Join-Path $repo "tools"
$logsDir  = Join-Path $toolsDir "logs"
New-Dir $toolsDir
New-Dir $logsDir

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = Join-Path $logsDir ("fix_review_one_shot_npmargs_{0}.log" -f $ts)
Write-Utf8NoBom $log ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))

function LogLine([string]$s){ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $s) -Encoding utf8 }

$backupDir = Join-Path $toolsDir ("backup_fix_review_one_shot_npmargs_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")
LogLine ("[INFO] BackupDir: {0}" -f $backupDir)

$target = Join-Path $repo "REVIEW_ONE_SHOT.ps1"
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { LogLine ("[FATAL] Missing: {0}" -f $target); exit 1 }

Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir "REVIEW_ONE_SHOT.ps1") -Force
LogLine "[INFO] Backed up REVIEW_ONE_SHOT.ps1"

$raw = Get-Content -LiteralPath $target -Raw

# Replace Invoke-Cmd function body with a safer implementation using .Arguments (string)
# This avoids ArgumentList edge cases and guarantees args reach npm on Windows.
$pattern = '(?s)function\s+Invoke-Cmd\s*\(\s*\[string\]\$Title,\s*\[string\]\$FilePath,\s*\[string\[\]\]\$Args,\s*\[string\]\$WorkDir,\s*\[int\]\$TimeoutSec\s*\)\s*\{.*?\n\}'
$replacement = @'
function Invoke-Cmd([string]$Title, [string]$FilePath, [string[]]$Args, [string]$WorkDir, [int]$TimeoutSec) {
  Log ("[RUN] {0}" -f $Title)

  $argStr = ""
  if ($Args -and $Args.Count -gt 0) {
    $escaped = @()
    foreach ($a in $Args) {
      if ($a -match '\s|"' ) { $escaped += ('"' + ($a -replace '"','\"') + '"') } else { $escaped += $a }
    }
    $argStr = ($escaped -join " ")
  }

  Log ("[CMD] {0} {1}" -f $FilePath, $argStr)

  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = $FilePath
  $pinfo.WorkingDirectory = $WorkDir
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError  = $true
  $pinfo.UseShellExecute = $false
  $pinfo.CreateNoWindow = $true
  $pinfo.Arguments = $argStr

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $pinfo
  [void]$p.Start()

  if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    try { $p.Kill($true) } catch {}
    Log ("[FAIL] Timeout after {0}s: {1}" -f $TimeoutSec, $Title)
    return @{ ok=$false; code=124; title=$Title }
  }

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $code = $p.ExitCode

  if ($stdout) { Log ("[OUT] " + ($stdout.TrimEnd())) }
  if ($stderr) { Log ("[ERR] " + ($stderr.TrimEnd())) }
  Log ("[EXIT] {0} => {1}" -f $Title, $code)

  return @{ ok=($code -eq 0); code=$code; title=$Title }
}
'@

$patched = [regex]::Replace($raw, $pattern, $replacement)
if ($patched -eq $raw) {
  LogLine "[FATAL] Could not locate Invoke-Cmd function to patch (pattern mismatch)."
  LogLine "[FATAL] EXIT CODE: 2"
  exit 2
}

Write-Utf8NoBom $target $patched
LogLine ("[PASS] Patched Invoke-Cmd in: {0}" -f $target)

$errs = Parse-Syntax $target
if ($errs -and $errs.Count -gt 0) {
  LogLine ("[FATAL] Parser errors: {0}" -f $errs.Count)
  foreach ($e in $errs) { LogLine ("[FATAL] {0} (Line {1}, Col {2})" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) }
  LogLine "[FATAL] EXIT CODE: 3"
  exit 3
}

LogLine "[PASS] Parser check OK"
LogLine "[PASS] EXIT CODE: 0"
exit 0
'@

# NOTE: write replacement as-is (UTF-8 no BOM)
# But $replacement is a here-string; to avoid terminator issues, we embed it as a single-quoted here-string safely:
# We'll just write with the content already in $patched above.

# (No-op: already wrote)
