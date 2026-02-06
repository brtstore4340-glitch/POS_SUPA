param(
  [string]$RepoRoot = (Get-Location).Path,
  [switch]$InstrumentIndexJs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function As-SingleString([object]$v, [string]$name) {
  if ($null -eq $v) { throw "$name is null" }
  if ($v -is [string]) { return $v }
  if ($v -is [System.Array]) {
    if ($v.Count -eq 0) { throw "$name is empty array" }
    if ($v.Count -gt 1) {
      Write-Host "WARN: $name is an array with $($v.Count) items. Using first item." -ForegroundColor Yellow
      Write-Host "      $name items: $($v -join ' | ')" -ForegroundColor Yellow
    }
    return [string]$v[0]
  }
  return [string]$v
}

$RepoRoot = As-SingleString $RepoRoot "RepoRoot"

$LogDir = Join-Path $RepoRoot ".boots-logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$runId = (Get-Date).ToString("yyyyMMdd-HHmmss")
$LogFile = Join-Path $LogDir "functions-timeout-scan-$runId.log"

function Log([string]$msg) {
  $ts = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
  "[$ts] $msg" | Tee-Object -FilePath $LogFile -Append | Out-Null
}

Log "START scan RepoRoot=$RepoRoot"

$firebaseJson = Join-Path $RepoRoot "firebase.json"
if (-not (Test-Path $firebaseJson)) { throw "firebase.json not found at $firebaseJson" }
Log "Found firebase.json"

$functionsDir = Join-Path $RepoRoot "functions"
if (-not (Test-Path $functionsDir)) { throw "functions directory not found at $functionsDir" }
Log "Found functions directory"

$targets = @(
  $firebaseJson,
  (Join-Path $functionsDir "package.json"),
  (Join-Path $functionsDir "index.js")
) | Where-Object { Test-Path $_ }

$backupDir = Join-Path $LogDir "backup-$runId"
New-Item -ItemType Directory -Path $backupDir | Out-Null

foreach ($f in $targets) {
  $dest = Join-Path $backupDir ([IO.Path]::GetFileName($f))
  Copy-Item -LiteralPath $f -Destination $dest -Force
  Log "Backed up: $f -> $dest"
}

$scanFiles = Get-ChildItem -Path $functionsDir -Recurse -File -Include *.js,*.cjs,*.mjs,*.json |
  Where-Object { $_.FullName -notmatch "\\node_modules\\" }

Log ("Scanning " + $scanFiles.Count + " files for common timeout triggers...")

$patterns = @(
  @{ Name="Top-level await"; Regex="(?m)^\s*await\s+" },
  @{ Name="Admin init at import"; Regex="initializeApp\s*\(" },
  @{ Name="Firestore client at import"; Regex="getFirestore\s*\(|firestore\s*\(\)" },
  @{ Name="FS read at import"; Regex="readFileSync\s*\(|readFile\s*\(" },
  @{ Name="Network at import"; Regex="axios\.\w+\s*\(|fetch\s*\(" },
  @{ Name="Secrets client"; Regex="SecretManagerServiceClient|accessSecretVersion" },
  @{ Name="Large deps"; Regex="require\(['""](puppeteer|playwright|sharp)['""]\)|from\s+['""](puppeteer|playwright|sharp)['""]" }
)

$findings = New-Object System.Collections.Generic.List[object]
foreach ($file in $scanFiles) {
  $text = Get-Content -Raw -LiteralPath $file.FullName
  foreach ($p in $patterns) {
    if ($text -match $p.Regex) {
      $findings.Add([pscustomobject]@{ File=$file.FullName; Pattern=$p.Name }) | Out-Null
    }
  }
}

$report = Join-Path $LogDir "functions-timeout-findings-$runId.csv"
$findings | Sort-Object File, Pattern | Export-Csv -NoTypeInformation -Path $report
Log "Wrote findings report: $report"

# OPTIONAL: instrument functions/index.js import timing (safe, minimal)
if ($InstrumentIndexJs) {
  $indexJs = Join-Path $functionsDir "index.js"
  if (-not (Test-Path $indexJs)) { throw "functions/index.js not found." }

  $src = Get-Content -Raw -LiteralPath $indexJs
  if ($src -notmatch "BOOT_IMPORT_TS") {
    $banner = @"
const BOOT_IMPORT_TS = Date.now();
console.log("[boot] index.js import start", new Date(BOOT_IMPORT_TS).toISOString());
process.on("beforeExit", () => console.log("[boot] beforeExit", Date.now() - BOOT_IMPORT_TS, "ms"));
"@
    $patched = $banner + "`r`n" + $src
    Set-Content -LiteralPath $indexJs -Value $patched -Encoding UTF8
    Log "Instrumented: $indexJs"
    Log "NOTE: This adds console logs during deploy discovery and runtime. Remove after debugging."
  } else {
    Log "Skipped instrumentation (already present)"
  }
}

Log "DONE scan"
Write-Host ""
Write-Host "Scan complete."
Write-Host "Log: $LogFile"
Write-Host "Findings: $report"
Write-Host "Backups: $backupDir"
