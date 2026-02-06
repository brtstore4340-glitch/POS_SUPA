# FILE: REVIEW_ONE_SHOT.ps1
# PURPOSE: One-shot project review (evidence + commands + report). No repo modifications.
param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,
  [int]$MaxFileKB = 256,
  [int]$TreeLimit = 250,
  [int]$TimeoutSec = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
  try {
    if ($script:LogFile) {
      Add-Content -LiteralPath $script:LogFile -Value ("[FATAL] " + $_.Exception.Message) -Encoding utf8
      Add-Content -LiteralPath $script:LogFile -Value "[FATAL] EXIT CODE: 1" -Encoding utf8
    }
  } catch {}
  exit 1
}

function New-Dir([string]$Path) { if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }
function Write-Utf8NoBom([string]$Path, [string]$Content) { $enc = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path, $Content, $enc) }
function Log([string]$Line) { $ts = (Get-Date).ToString("s"); Add-Content -LiteralPath $script:LogFile -Value ("[{0}] {1}" -f $ts, $Line) -Encoding utf8 }
function Assert-Dir([string]$Path, [string]$Name) { if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw ("Missing {0} directory: {1}" -f $Name, $Path) } }

function Get-RepoScripts([string]$PkgPath) {
  try { $json = Get-Content -LiteralPath $PkgPath -Raw | ConvertFrom-Json; if ($null -ne $json.scripts) { return $json.scripts.PSObject.Properties.Name } } catch {}
  return @()
}

function Invoke-CmdLine([string]$Title, [string]$CmdLine, [string]$WorkDir, [int]$TimeoutSec) {
  Log ("[RUN] {0}" -f $Title)
  Log ("[CMD] cmd.exe /c {0}" -f $CmdLine)

  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = "cmd.exe"
  $pinfo.WorkingDirectory = $WorkDir
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError  = $true
  $pinfo.UseShellExecute = $false
  $pinfo.CreateNoWindow = $true
  $pinfo.Arguments = "/c " + $CmdLine

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

# --- MAIN ---
$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
Assert-Dir $repo "RepoRoot"

$toolsDir  = Join-Path $repo "tools"
$logsDir   = Join-Path $toolsDir "logs"
$reviewDir = Join-Path $toolsDir "review"
New-Dir $toolsDir; New-Dir $logsDir; New-Dir $reviewDir

$ts = (Get-Date -Format "yyyyMMdd_HHmmss")
$script:LogFile = Join-Path $logsDir ("review_one_shot_{0}.log" -f $ts)
Write-Utf8NoBom $script:LogFile ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))

$backupDir = Join-Path $toolsDir ("backup_review_one_shot_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")
Log ("[INFO] BackupDir: {0}" -f $backupDir)

$Fence = [string]::new([char]96, 3)

$evidence = New-Object System.Collections.Generic.List[string]
$mustFix  = New-Object System.Collections.Generic.List[string]
$nice     = New-Object System.Collections.Generic.List[string]
function Add-E([string]$s){ $evidence.Add($s) | Out-Null }
function Add-M([string]$s){ $mustFix.Add($s) | Out-Null }
function Add-N([string]$s){ $nice.Add($s) | Out-Null }

$pkg = Join-Path $repo "package.json"
if (-not (Test-Path -LiteralPath $pkg -PathType Leaf)) { Add-M "Missing package.json at repo root (cannot run verify build)." } else { Add-E "package.json found" }

$scripts = @()
if (Test-Path -LiteralPath $pkg -PathType Leaf) {
  $scripts = Get-RepoScripts $pkg
  Add-E ("package.json scripts: " + ($scripts -join ", "))
}

$pm = "npm"
if (Test-Path -LiteralPath (Join-Path $repo "pnpm-lock.yaml")) { $pm = "pnpm" }
elseif (Test-Path -LiteralPath (Join-Path $repo "yarn.lock"))  { $pm = "yarn" }
Add-E ("Package manager inferred: " + $pm)

$cmdResults = @()
$nm = Join-Path $repo "node_modules"
if (-not (Test-Path -LiteralPath $nm -PathType Container)) {
  if ($pm -eq "npm")      { $cmdResults += Invoke-CmdLine "Install (npm ci)"  "npm ci" $repo $TimeoutSec }
  elseif ($pm -eq "pnpm") { $cmdResults += Invoke-CmdLine "Install (pnpm i)" "pnpm i --frozen-lockfile" $repo $TimeoutSec }
  else                    { $cmdResults += Invoke-CmdLine "Install (yarn install)" "yarn install --frozen-lockfile" $repo $TimeoutSec }
} else { Log "[INFO] node_modules exists; skipping install." }

if ($scripts -contains "test")  {
  if ($pm -eq "npm")      { $cmdResults += Invoke-CmdLine "Tests" "npm run test" $repo $TimeoutSec }
  elseif ($pm -eq "pnpm") { $cmdResults += Invoke-CmdLine "Tests" "pnpm run test" $repo $TimeoutSec }
  else                    { $cmdResults += Invoke-CmdLine "Tests" "yarn test" $repo $TimeoutSec }
} else { Add-N "No script 'test' in package.json." }

if ($scripts -contains "build") {
  if ($pm -eq "npm")      { $cmdResults += Invoke-CmdLine "Build" "npm run build" $repo $TimeoutSec }
  elseif ($pm -eq "pnpm") { $cmdResults += Invoke-CmdLine "Build" "pnpm run build" $repo $TimeoutSec }
  else                    { $cmdResults += Invoke-CmdLine "Build" "yarn build" $repo $TimeoutSec }
} else { Add-N "No script 'build' in package.json." }

$hardFail = $false
foreach ($r in $cmdResults) { if (-not $r.ok) { $hardFail = $true } }
if ($hardFail) { Add-M "One or more verify commands failed (see tools/logs for exit codes and stderr)." }

$tree = Get-ChildItem -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue |
  Where-Object {
    $_.FullName -notmatch "\\node_modules\\" -and
    $_.FullName -notmatch "\\dist\\" -and
    $_.FullName -notmatch "\\build\\" -and
    $_.FullName -notmatch "\\.firebase\\" -and
    $_.FullName -notmatch "\\tools\\backup_" -and
    $_.FullName -notmatch "\\tools\\logs\\"
  } | Select-Object -First $TreeLimit | ForEach-Object { $_.FullName.Substring($repo.Length).TrimStart("\") }
Add-E ("Repo tree captured: top " + $TreeLimit)

$reportPath = Join-Path $reviewDir ("REVIEW_{0}.md" -f $ts)
$rep = New-Object System.Text.StringBuilder
[void]$rep.AppendLine("# PROJECT REVIEW " + $ts)
[void]$rep.AppendLine("")
[void]$rep.AppendLine("RepoRoot: " + $repo)
[void]$rep.AppendLine("")
[void]$rep.AppendLine("## Evidence")
foreach ($e in $evidence) { [void]$rep.AppendLine("- " + $e) }
[void]$rep.AppendLine("")
[void]$rep.AppendLine("## Quick Tree (top " + $TreeLimit + ")")
[void]$rep.AppendLine($Fence)
[void]$rep.AppendLine(($tree -join "`r`n"))
[void]$rep.AppendLine($Fence)
[void]$rep.AppendLine("")
[void]$rep.AppendLine("## Decision")
if ($mustFix.Count -gt 0 -or $hardFail) { [void]$rep.AppendLine("- Verdict: NEEDS FIX") } else { [void]$rep.AppendLine("- Verdict: PASS") }
[void]$rep.AppendLine("")
[void]$rep.AppendLine("## Findings Must-fix")
if ($mustFix.Count -eq 0) { [void]$rep.AppendLine("- (none)") } else { foreach ($f in $mustFix) { [void]$rep.AppendLine("- " + $f) } }
[void]$rep.AppendLine("")
[void]$rep.AppendLine("## Findings Nice-to-have")
if ($nice.Count -eq 0) { [void]$rep.AppendLine("- (none)") } else { foreach ($f in $nice) { [void]$rep.AppendLine("- " + $f) } }
[void]$rep.AppendLine("")
[void]$rep.AppendLine("## Command Results (summary)")
if ($cmdResults.Count -eq 0) { [void]$rep.AppendLine("- (no commands were run)") } else { $i=0; foreach ($r in $cmdResults) { $i++; [void]$rep.AppendLine(("- #{0}: {1} code={2}" -f $i, $r.title, $r.code)) } }

Write-Utf8NoBom $reportPath $rep.ToString()
Log ("[PASS] Wrote report: {0}" -f $reportPath)
if ($mustFix.Count -gt 0 -or $hardFail) { Log "[DONE] EXIT CODE: 2"; exit 2 }
Log "[DONE] EXIT CODE: 0"; exit 0