# boots-functions-remove-instrumentation.ps1
param(
  [string]$RepoRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function As-SingleString([object]$v, [string]$name) {
  if ($v -is [string]) { return $v }
  if ($v -is [System.Array]) { return [string]$v[0] }
  return [string]$v
}

$RepoRoot = As-SingleString $RepoRoot "RepoRoot"
$LogDir = Join-Path $RepoRoot ".boots-logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$runId = (Get-Date).ToString("yyyyMMdd-HHmmss")
$backupDir = Join-Path $LogDir "backup-remove-instr-$runId"
New-Item -ItemType Directory -Path $backupDir | Out-Null

$indexJs = Join-Path $RepoRoot "functions\index.js"
if (-not (Test-Path $indexJs)) { throw "Missing: $indexJs" }

Copy-Item -LiteralPath $indexJs -Destination (Join-Path $backupDir "index.js") -Force

$src = Get-Content -Raw -LiteralPath $indexJs

# Remove the exact injected block we added (BOOT_IMPORT_TS + 2 logs)
$pattern = [regex]::Escape('const BOOT_IMPORT_TS = Date.now();') +
           '(.|\r|\n)*?' +
           [regex]::Escape('process.on("beforeExit", () => console.log("[boot] beforeExit", Date.now() - BOOT_IMPORT_TS, "ms"));') +
           '\s*'

if ($src -match $pattern) {
  $patched = [regex]::Replace($src, $pattern, "", 1)
  Set-Content -LiteralPath $indexJs -Value $patched -Encoding UTF8
  Write-Host "Removed instrumentation from functions/index.js"
  Write-Host "Backup: $backupDir\index.js"
} else {
  Write-Host "No instrumentation block found. No changes made."
  Write-Host "Backup still created: $backupDir\index.js"
}

Write-Host ""
Write-Host "Local load-time check command:"
Write-Host "  node -e `"const t=Date.now(); require('./functions/index.js'); console.log('load_ms', Date.now()-t);`""
