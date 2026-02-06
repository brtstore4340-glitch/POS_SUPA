# FILE: FIX_REVIEW_PROJECT_FULL_FENCE_JOIN.ps1
# PURPOSE: Patch $Fence generation to avoid invalid [char]*[int] and avoid literal backtick; backup+logs+parse-check.
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\FIX_REVIEW_PROJECT_FULL_FENCE_JOIN.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
  try { Write-Host ("[FATAL] " + $_.Exception.Message) } catch {}
  exit 1
}

function New-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function LogLine([string]$LogFile, [string]$Line) {
  Add-Content -LiteralPath $LogFile -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $Line) -Encoding utf8
}

function Parse-Syntax([string]$FilePath) {
  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errors)
  return $errors
}

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$toolsDir = Join-Path $repo "tools"
$logsDir  = Join-Path $toolsDir "logs"
New-Dir $toolsDir
New-Dir $logsDir

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = Join-Path $logsDir ("fix_review_fence_join_{0}.log" -f $ts)
Write-Utf8NoBom $log ("[INFO] RepoRoot: {0}`n[INFO] Start: {1}`n" -f $repo, (Get-Date).ToString("s"))

$backupDir = Join-Path $toolsDir ("backup_fix_review_fence_join_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`n")
LogLine $log ("[INFO] BackupDir: {0}" -f $backupDir)

$target = Join-Path $repo "REVIEW_PROJECT_FULL.ps1"
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
  LogLine $log ("[FATAL] Missing target: {0}" -f $target)
  LogLine $log "[FATAL] EXIT CODE: 1"
  exit 1
}

Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir "REVIEW_PROJECT_FULL.ps1") -Force
LogLine $log "[INFO] Backed up REVIEW_PROJECT_FULL.ps1"

$raw = Get-Content -LiteralPath $target -Raw

# Replace ANY $Fence assignment line with safe join version.
# Safe: no backtick literal; no char multiply.
$replacement = '$Fence = -join (1..3 | ForEach-Object { [char]96 })'
$patched = [regex]::Replace(
  $raw,
  '(?m)^\s*\$Fence\s*=.*$',
  $replacement
)

if ($patched -eq $raw) {
  LogLine $log "[WARN] No $Fence assignment found; inserting after backup lines."
  # Insert after first occurrence of $ctxPath assignment as a stable anchor
  if ($patched -match '(?m)^\s*\$ctxPath\s*=.*$') {
    $patched = [regex]::Replace(
      $patched,
      '(?m)^\s*\$s*\$ctxPath\s*=.*$',
      '$0' + "`r`n" + $replacement,
      1
    )
  } else {
    # Fallback: insert near top after ErrorActionPreference
    $patched = [regex]::Replace(
      $patched,
      '(?m)^\$ErrorActionPreference\s*=\s*".*"\s*$',
      '$0' + "`r`n" + $replacement,
      1
    )
  }
} else {
  LogLine $log "[PASS] Patched $Fence assignment."
}

Write-Utf8NoBom $target $patched
LogLine $log ("[PASS] Wrote patched file: {0}" -f $target)

$errs = Parse-Syntax $target
if ($errs -and $errs.Count -gt 0) {
  LogLine $log ("[FATAL] Parser errors: {0}" -f $errs.Count)
  foreach ($e in $errs) { LogLine $log ("[FATAL] {0} (Line {1}, Col {2})" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) }
  LogLine $log "[FATAL] EXIT CODE: 2"
  exit 2
}

LogLine $log "[PASS] Parser check OK"
LogLine $log "[PASS] EXIT CODE: 0"
exit 0
