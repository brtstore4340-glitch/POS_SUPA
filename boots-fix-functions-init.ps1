param(
  [string]$RepoRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function As-SingleString([object]$v) {
  if ($v -is [string]) { return $v }
  if ($v -is [System.Array]) { return [string]$v[0] }
  return [string]$v
}

$RepoRoot = As-SingleString $RepoRoot
$logDir = Join-Path $RepoRoot ".boots-logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$runId = (Get-Date).ToString("yyyyMMdd-HHmmss")
$logFile = Join-Path $logDir "fix-functions-init-$runId.log"
$backupDir = Join-Path $logDir "backup-fix-functions-init-$runId"
New-Item -ItemType Directory -Path $backupDir | Out-Null

function Log([string]$msg) {
  $ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
  "[$ts] $msg" | Tee-Object -FilePath $logFile -Append | Out-Null
}

$indexJs = Join-Path $RepoRoot "functions\index.js"
if (-not (Test-Path $indexJs)) { throw "Missing: $indexJs" }

Copy-Item -LiteralPath $indexJs -Destination (Join-Path $backupDir "index.js") -Force
Log "Backed up functions/index.js -> $backupDir\index.js"

$src = Get-Content -Raw -LiteralPath $indexJs

# 1) Remove boot instrumentation block (if present)
$instrPattern = "(?s)^\s*const\s+BOOT_IMPORT_TS\s*=\s*Date\.now\(\);\s*\r?\n" +
                ".*?\r?\n" +
                ".*?process\.on\(""beforeExit"".*?\);\s*\r?\n"
if ($src -match $instrPattern) {
  $src = [regex]::Replace($src, $instrPattern, "", 1)
  Log "Removed BOOT_IMPORT_TS instrumentation header"
} else {
  Log "No BOOT_IMPORT_TS header found (skipped)"
}

# 2) Remove eager ensureAdmin() call (keep function definition)
# Matches a line containing ONLY ensureAdmin();
$eagerPattern = "(?m)^\s*ensureAdmin\(\);\s*$\r?\n?"
$before = $src
$src = [regex]::Replace($src, $eagerPattern, "", 1)
if ($before -ne $src) {
  Log "Removed eager ensureAdmin() call (lazy init only)"
} else {
  Log "Eager ensureAdmin() call not found (skipped)"
}

# 3) Add a small comment guardrail if not present
if ($src -notmatch "FAST_IMPORT_GUARDRAIL") {
  $guard = "/* FAST_IMPORT_GUARDRAIL: Do not perform network/DB/init work at module load. Keep admin/firestore lazy. */`r`n"
  $src = $guard + $src
  Log "Added FAST_IMPORT_GUARDRAIL comment"
}

Set-Content -LiteralPath $indexJs -Value $src -Encoding UTF8
Log "Wrote patched functions/index.js"

Write-Host "Patched: $indexJs"
Write-Host "Backup:  $backupDir\index.js"
Write-Host "Log:     $logFile"
Write-Host ""
Write-Host "Quick local load-time check:"
Write-Host "  node -e `"const t=Date.now(); require('./functions/index.js'); console.log('load_ms', Date.now()-t);`""
