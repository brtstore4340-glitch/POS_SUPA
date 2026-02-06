# FILE: RUN_REVIEW_AND_SHOW_LATEST.ps1
# PURPOSE: Run REVIEW_PROJECT_FULL.ps1 then print latest report + log. SafeMode + logs + no assumptions.
param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
  Write-Host ("[FATAL] " + $_.Exception.Message)
  exit 1
}

function Assert-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Missing directory: $Path" }
}

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
Assert-Dir $repo

$review = Join-Path $repo "REVIEW_PROJECT_FULL.ps1"
if (-not (Test-Path -LiteralPath $review -PathType Leaf)) { throw "Missing script: $review" }

& pwsh -ExecutionPolicy Bypass -File $review -RepoRoot $repo
$exit = $LASTEXITCODE

$reviewDir = Join-Path $repo "tools\review"
$logsDir   = Join-Path $repo "tools\logs"

Write-Host ("[INFO] REVIEW exit code: {0}" -f $exit)

if (Test-Path -LiteralPath $reviewDir) {
  $latestReport = Get-ChildItem -LiteralPath $reviewDir -Filter "REVIEW_*.md" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if ($latestReport) {
    Write-Host ("`n===== LATEST REPORT: {0} =====" -f $latestReport.FullName)
    Get-Content -LiteralPath $latestReport.FullName -Raw
  } else {
    Write-Host "[WARN] No REVIEW_*.md found."
  }
} else {
  Write-Host ("[WARN] Missing directory: {0}" -f $reviewDir)
}

if (Test-Path -LiteralPath $logsDir) {
  $latestLog = Get-ChildItem -LiteralPath $logsDir -Filter "review_full_*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if ($latestLog) {
    Write-Host ("`n===== LATEST LOG: {0} =====" -f $latestLog.FullName)
    Get-Content -LiteralPath $latestLog.FullName -Raw
  } else {
    Write-Host "[WARN] No review_full_*.log found."
  }
} else {
  Write-Host ("[WARN] Missing directory: {0}" -f $logsDir)
}

exit $exit
