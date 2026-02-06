# FILE: PATCH_REVIEW_ONE_SHOT_VITEST_CI.ps1
# PURPOSE: Force vitest to run in CI mode (exit reliably) inside REVIEW_ONE_SHOT.ps1, then run review.
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\PATCH_REVIEW_ONE_SHOT_VITEST_CI.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
trap { try { Write-Host ("[FATAL] " + $_.Exception.Message) } catch {}; exit 1 }

function New-Dir([string]$Path){ if(-not (Test-Path -LiteralPath $Path)){ New-Item -ItemType Directory -Path $Path -Force | Out-Null } }
function Write-Utf8NoBom([string]$Path,[string]$Content){ $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$Content,$enc) }
function Parse-Syntax([string]$FilePath){ $t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($FilePath,[ref]$t,[ref]$e); return $e }

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$tools = Join-Path $repo "tools"
$logs  = Join-Path $tools "logs"
New-Dir $tools
New-Dir $logs

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = Join-Path $logs ("patch_review_one_shot_vitest_ci_{0}.log" -f $ts)
Write-Utf8NoBom $log ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))
function LogLine([string]$s){ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $s) -Encoding utf8 }

$backupDir = Join-Path $tools ("backup_patch_review_one_shot_vitest_ci_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $tools "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")
LogLine ("[INFO] BackupDir: {0}" -f $backupDir)

$target = Join-Path $repo "REVIEW_ONE_SHOT.ps1"
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { LogLine ("[FATAL] Missing: {0}" -f $target); exit 2 }

Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir "REVIEW_ONE_SHOT.ps1") -Force
LogLine "[INFO] Backed up REVIEW_ONE_SHOT.ps1"

$raw = Get-Content -LiteralPath $target -Raw

# Replace ONLY the vitest command line:
# from:  npm exec -- vitest
# to:    npm exec -- vitest run --watch=false --reporter=verbose
$before = 'npm exec -- vitest'
$after  = 'npm exec -- vitest run --watch=false --reporter=verbose'

if ($raw -notmatch [regex]::Escape($before)) {
  LogLine "[FATAL] Could not find expected vitest cmd string to patch."
  LogLine "[HINT] Expected to find: npm exec -- vitest"
  exit 3
}

$patched = $raw -replace [regex]::Escape($before), $after
Write-Utf8NoBom $target $patched
LogLine ("[PASS] Patched vitest cmd: {0}" -f $after)

$errs = Parse-Syntax $target
if ($errs -and $errs.Count -gt 0) {
  LogLine ("[FATAL] Parser errors after patch: {0}" -f $errs.Count)
  foreach ($e in $errs) { LogLine ("[FATAL] {0} (Line {1}, Col {2})" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) }
  exit 4
}
LogLine "[PASS] Parser check OK"

& pwsh -ExecutionPolicy Bypass -File $target -RepoRoot $repo
$rc = $LASTEXITCODE
LogLine ("[EXIT] REVIEW_ONE_SHOT.ps1 => {0}" -f $rc)

Write-Host ("[OK] Patch log: {0}" -f $log)
exit $rc
