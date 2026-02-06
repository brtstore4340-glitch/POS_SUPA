# FILE: REVIEW_PROJECT_FULL.ps1
# PURPOSE: Full project review runner (evidence + commands + report). No code modifications.
# USAGE:
#   pwsh -ExecutionPolicy Bypass -File .\REVIEW_PROJECT_FULL.ps1 -RepoRoot "D:\path\to\repo"
#   pwsh -ExecutionPolicy Bypass -File .\REVIEW_PROJECT_FULL.ps1 -RepoRoot "D:\path\to\repo" -MaxFileKB 256 -TimeoutSec 1800

param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,

  [int]$MaxFileKB = 256,        # safety cap per file capture
  [int]$MaxFiles  = 2500,       # cap for file enumeration
  [int]$TimeoutSec = 1800       # per command timeout
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
  try {
    $msg = $_.Exception.Message
    if ($script:LogFile) {
      Add-Content -LiteralPath $script:LogFile -Value ("[FATAL] {0}" -f $msg) -Encoding utf8
      Add-Content -LiteralPath $script:LogFile -Value ("[FATAL] EXIT CODE: 1") -Encoding utf8
    }
  } catch {}
  exit 1
}

function New-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function NowTs() { (Get-Date).ToString("yyyyMMdd_HHmmss") }

function Log([string]$Line) {
  $ts = (Get-Date).ToString("s")
  Add-Content -LiteralPath $script:LogFile -Value ("[{0}] {1}" -f $ts, $Line) -Encoding utf8
}

function Assert-Dir([string]$Path, [string]$Name) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw ("Missing {0} directory: {1}" -f $Name, $Path)
  }
}

function Backup-IfExists([string]$FilePath, [string]$BackupDir) {
  if (Test-Path -LiteralPath $FilePath -PathType Leaf) {
    Copy-Item -LiteralPath $FilePath -Destination (Join-Path $BackupDir (Split-Path $FilePath -Leaf)) -Force
    Log ("[INFO] Backed up: {0}" -f $FilePath)
  }
}

function Get-RepoScripts([string]$PkgPath) {
  try {
    $json = Get-Content -LiteralPath $PkgPath -Raw | ConvertFrom-Json
    if ($null -ne $json.scripts) { return $json.scripts.PSObject.Properties.Name }
  } catch {}
  return @()
}

function Invoke-Cmd([string]$Title, [string]$FilePath, [string[]]$Args, [string]$WorkDir) {
  Log ("[RUN] {0}" -f $Title)
  Log ("[CMD] {0} {1}" -f $FilePath, ($Args -join " "))
  $out = New-Object System.Text.StringBuilder
  $err = New-Object System.Text.StringBuilder

  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = $FilePath
  $pinfo.WorkingDirectory = $WorkDir
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError  = $true
  $pinfo.UseShellExecute = $false
  $pinfo.CreateNoWindow = $true
  foreach ($a in $Args) { [void]$pinfo.ArgumentList.Add($a) }

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $pinfo
  [void]$p.Start()

  if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    try { $p.Kill($true) } catch {}
    Log ("[FAIL] Timeout after {0}s: {1}" -f $TimeoutSec, $Title)
    return @{ ok=$false; code=124; stdout=""; stderr="TIMEOUT" }
  }

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $code = $p.ExitCode

  if ($stdout) { Log ("[OUT] " + ($stdout.TrimEnd())) }
  if ($stderr) { Log ("[ERR] " + ($stderr.TrimEnd())) }
  Log ("[EXIT] {0} => {1}" -f $Title, $code)

  return @{ ok=($code -eq 0); code=$code; stdout=$stdout; stderr=$stderr }
}

function Safe-ReadSnippet([string]$Path, [int]$MaxKB) {
  try {
    $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($fi.Length -gt ($MaxKB * 1024)) {
      return ("(skipped: {0} KB > cap {1} KB)" -f [int]([math]::Ceiling($fi.Length/1024)), $MaxKB)
    }
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if ($raw.Length -gt 6000) { return $raw.Substring(0,6000) + "`n... (truncated)" }
    return $raw
  } catch {
    return "(read failed: $($_.Exception.Message))"
  }
}

# --- main ---
$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
Assert-Dir $repo "RepoRoot"

$toolsDir  = Join-Path $repo "tools"
$logsDir   = Join-Path $toolsDir "logs"
$reviewDir = Join-Path $toolsDir "review"
$ctxDir    = Join-Path $toolsDir "context"
New-Dir $toolsDir
New-Dir $logsDir
New-Dir $reviewDir
New-Dir $ctxDir

$ts = NowTs
$script:LogFile = Join-Path $logsDir ("review_full_{0}.log" -f $ts)
Write-Utf8NoBom $script:LogFile ("[INFO] RepoRoot: {0}`n[INFO] Start: {1}`n" -f $repo, (Get-Date).ToString("s"))

$backupDir = Join-Path $toolsDir ("backup_review_full_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`n")
Log ("[INFO] BackupDir: {0}" -f $backupDir)

$reportPath = Join-Path $reviewDir ("REVIEW_{0}.md" -f $ts)
$ctxPath    = Join-Path $ctxDir ("CONTEXT_PACK_{0}.md" -f $ts)
Backup-IfExists $reportPath $backupDir
Backup-IfExists $ctxPath $backupDir

# Enumerate key files (evidence map)
$includeTop = @(
  "package.json","pnpm-lock.yaml","package-lock.json","yarn.lock",
  "firebase.json","firestore.rules","storage.rules",".firebaserc",
  "tsconfig.json","vite.config.*","vitest.config.*","jest.config.*",
  "docs","plans","src","functions"
)

Log "[INFO] Scanning repository tree..."
$allFiles = Get-ChildItem -LiteralPath $repo -Recurse -File -Force -ErrorAction SilentlyContinue |
  Where-Object {
    $_.FullName -notmatch '\\node_modules\\' -and
    $_.FullName -notmatch '\\dist\\' -and
    $_.FullName -notmatch '\\build\\' -and
    $_.FullName -notmatch '\\.firebase\\' -and
    $_.FullName -notmatch '\\.vite\\' -and
    $_.FullName -notmatch '\\tools\\backup_' -and
    $_.FullName -notmatch '\\tools\\logs\\'
  } |
  Select-Object -First $MaxFiles

Log ("[INFO] FilesEnumerated: {0}" -f ($allFiles.Count))

# Context pack (evidence-of-state)
$ctx = New-Object System.Text.StringBuilder
[void]$ctx.AppendLine("# CONTEXT_PACK — $ts")
[void]$ctx.AppendLine("")
[void]$ctx.AppendLine("RepoRoot: $repo")
[void]$ctx.AppendLine("Generated: " + (Get-Date).ToString("s"))
[void]$ctx.AppendLine("")
[void]$ctx.AppendLine("## Key Files (snippets, capped)")
[void]$ctx.AppendLine("")

$keyList = @(
  "package.json",
  "firebase.json",
  "firestore.rules",
  "tsconfig.json",
  ".firebaserc"
)

foreach ($k in $keyList) {
  $p = Join-Path $repo $k
  if (Test-Path -LiteralPath $p -PathType Leaf) {
    [void]$ctx.AppendLine("### $k")
    [void]$ctx.AppendLine("```")
    [void]$ctx.AppendLine((Safe-ReadSnippet $p $MaxFileKB))
    [void]$ctx.AppendLine("```")
    [void]$ctx.AppendLine("")
  }
}

# directory snapshots
$dirs = @("docs","plans","src","functions","tools")
foreach ($d in $dirs) {
  $dp = Join-Path $repo $d
  if (Test-Path -LiteralPath $dp -PathType Container) {
    [void]$ctx.AppendLine("## Tree: $d (top 200)")
    [void]$ctx.AppendLine("```")
    $tree = Get-ChildItem -LiteralPath $dp -Recurse -Force -ErrorAction SilentlyContinue |
      Select-Object -First 200 |
      ForEach-Object { $_.FullName.Substring($repo.Length).TrimStart("\") }
    [void]$ctx.AppendLine(($tree -join "`n"))
    [void]$ctx.AppendLine("```")
    [void]$ctx.AppendLine("")
  }
}

Write-Utf8NoBom $ctxPath $ctx.ToString()
Log ("[PASS] Wrote context pack: {0}" -f $ctxPath)

# Static review checks
$findingsMust   = New-Object System.Collections.Generic.List[string]
$findingsShould = New-Object System.Collections.Generic.List[string]
$findingsNice   = New-Object System.Collections.Generic.List[string]
$evidence       = New-Object System.Collections.Generic.List[string]

function Add-Evidence([string]$Item) { $evidence.Add($Item) | Out-Null }
function Add-Must([string]$Item)     { $findingsMust.Add($Item) | Out-Null }
function Add-Should([string]$Item)   { $findingsShould.Add($Item) | Out-Null }
function Add-Nice([string]$Item)     { $findingsNice.Add($Item) | Out-Null }

# Evidence: scripts, rules, functions existence
$pkg = Join-Path $repo "package.json"
if (Test-Path -LiteralPath $pkg) { Add-Evidence "package.json (scripts inspected)" } else { Add-Must "Missing package.json at repo root (cannot verify build reliably)" }

$rules = Join-Path $repo "firestore.rules"
if (Test-Path -LiteralPath $rules) {
  Add-Evidence "firestore.rules (deny-by-default posture quick scan)"
  $txt = (Get-Content -LiteralPath $rules -Raw -ErrorAction SilentlyContinue)
  if ($txt -and ($txt -notmatch 'allow\s+read|allow\s+write')) {
    Add-Should "firestore.rules has no allow rules detected (verify intended; may block app)"
  }
  if ($txt -and ($txt -match 'allow\s+read\s*:\s*if\s*true|allow\s+write\s*:\s*if\s*true')) {
    Add-Must "firestore.rules contains allow read/write if true (deny-by-default violated)"
  }
} else {
  Add-Should "No firestore.rules found at repo root (if using Firestore, add deny-by-default rules)"
}

# Secrets risk quick scan (do not print values)
$envFiles = Get-ChildItem -LiteralPath $repo -File -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^\.env(\.|$)' -or $_.Name -match 'firebase.*\.json$' } |
  Select-Object -First 20
if ($envFiles.Count -gt 0) {
  Add-Evidence (".env-like files detected: " + (($envFiles | ForEach-Object {$_.Name}) -join ", "))
  Add-Should "Confirm .env* are gitignored and secrets are not committed"
}

# Command runs (auto-detect)
$cmdResults = @()
if (Test-Path -LiteralPath $pkg) {
  $scripts = Get-RepoScripts $pkg
  Log ("[INFO] package.json scripts: {0}" -f ($scripts -join ", "))

  # package manager pick
  $pm = "npm"
  if (Test-Path -LiteralPath (Join-Path $repo "pnpm-lock.yaml")) { $pm = "pnpm" }
  elseif (Test-Path -LiteralPath (Join-Path $repo "yarn.lock"))  { $pm = "yarn" }
  elseif (Test-Path -LiteralPath (Join-Path $repo "package-lock.json")) { $pm = "npm" }

  Add-Evidence ("Package manager inferred: " + $pm)

  # install step (safe: only if node_modules missing)
  $nm = Join-Path $repo "node_modules"
  if (-not (Test-Path -LiteralPath $nm -PathType Container)) {
    if ($pm -eq "npm") {
      $cmdResults += (Invoke-Cmd "Install (npm ci)" "npm" @("ci") $repo)
    } elseif ($pm -eq "pnpm") {
      $cmdResults += (Invoke-Cmd "Install (pnpm i)" "pnpm" @("i","--frozen-lockfile") $repo)
    } else {
      $cmdResults += (Invoke-Cmd "Install (yarn install)" "yarn" @("install","--frozen-lockfile") $repo)
    }
  } else {
    Log "[INFO] node_modules exists; skipping install."
  }

  $want = @(
    @{name="lint";       title="Lint"},
    @{name="typecheck";  title="Typecheck"},
    @{name="test";       title="Tests"},
    @{name="build";      title="Build"}
  )

  foreach ($w in $want) {
    if ($scripts -contains $w.name) {
      if ($pm -eq "npm")      { $cmdResults += (Invoke-Cmd $w.title "npm"  @("run",$w.name) $repo) }
      elseif ($pm -eq "pnpm") { $cmdResults += (Invoke-Cmd $w.title "pnpm" @("run",$w.name) $repo) }
      else                    { $cmdResults += (Invoke-Cmd $w.title "yarn" @($w.name) $repo) }
    } else {
      Add-Nice ("No script '" + $w.name + "' in package.json (ok if intentional)")
    }
  }
}

# Evaluate results
$hardFail = $false
foreach ($r in $cmdResults) {
  if (-not $r.ok) { $hardFail = $true }
}

if ($hardFail) {
  Add-Must "One or more verify commands failed (see log + report for exit codes)"
}

# Write report
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# PROJECT REVIEW — $ts")
[void]$md.AppendLine("")
[void]$md.AppendLine("RepoRoot: `$repo`")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Evidence")
foreach ($e in $evidence) { [void]$md.AppendLine("- " + $e) }
[void]$md.AppendLine("- Context pack: `tools/context/$(Split-Path $ctxPath -Leaf)`")
[void]$md.AppendLine("- Log: `tools/logs/$(Split-Path $script:LogFile -Leaf)`")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Decision")
if ($findingsMust.Count -gt 0) {
  [void]$md.AppendLine("- Verdict: **NEEDS FIX** (must-fix present)")
} elseif ($hardFail) {
  [void]$md.AppendLine("- Verdict: **BLOCKED** (verify failed)")
} else {
  [void]$md.AppendLine("- Verdict: **PASS** (no must-fix found by this runner)")
}
[void]$md.AppendLine("")
[void]$md.AppendLine("## Findings — Must-fix")
if ($findingsMust.Count -eq 0) { [void]$md.AppendLine("- (none)") }
else { foreach ($f in $findingsMust) { [void]$md.AppendLine("- " + $f) } }

[void]$md.AppendLine("")
[void]$md.AppendLine("## Findings — Should-fix")
if ($findingsShould.Count -eq 0) { [void]$md.AppendLine("- (none)") }
else { foreach ($f in $findingsShould) { [void]$md.AppendLine("- " + $f) } }

[void]$md.AppendLine("")
[void]$md.AppendLine("## Findings — Nice-to-have")
if ($findingsNice.Count -eq 0) { [void]$md.AppendLine("- (none)") }
else { foreach ($f in $findingsNice) { [void]$md.AppendLine("- " + $f) } }

[void]$md.AppendLine("")
[void]$md.AppendLine("## Command Results (summary)")
if ($cmdResults.Count -eq 0) {
  [void]$md.AppendLine("- (no commands were run)")
} else {
  $i = 0
  foreach ($r in $cmdResults) {
    $i++
    [void]$md.AppendLine(("- #{0}: ok={1} code={2}" -f $i, $r.ok, $r.code))
  }
}

Write-Utf8NoBom $reportPath $md.ToString()
Log ("[PASS] Wrote report: {0}" -f $reportPath)

# Exit code policy:
# 0 = pass, 2 = needs fix (must), 1 = runner error/timeout/blocked
if ($findingsMust.Count -gt 0 -or $hardFail) {
  Log "[DONE] EXIT CODE: 2"
  exit 2
}

Log "[DONE] EXIT CODE: 0"
exit 0
