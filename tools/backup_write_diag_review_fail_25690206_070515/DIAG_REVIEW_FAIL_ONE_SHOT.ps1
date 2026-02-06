# FILE: DIAG_REVIEW_FAIL_ONE_SHOT.ps1
# PURPOSE: Collect full evidence for REVIEW_ONE_SHOT failures (vitest/vite) with verbose stderr, no repo modifications.
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\DIAG_REVIEW_FAIL_ONE_SHOT.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,

  [int]$TimeoutSec = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
  try { Write-Host ("[FATAL] " + $_.Exception.Message) } catch {}
  exit 1
}

function New-Dir([string]$Path) { if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }
function Write-Utf8NoBom([string]$Path, [string]$Content) { $enc = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path, $Content, $enc) }
function Assert-Dir([string]$Path, [string]$Name) { if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw ("Missing {0} directory: {1}" -f $Name, $Path) } }
function NowTs() { (Get-Date).ToString("yyyyMMdd_HHmmss") }

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
Assert-Dir $repo "RepoRoot"

$toolsDir  = Join-Path $repo "tools"
$logsDir   = Join-Path $toolsDir "logs"
$reviewDir = Join-Path $toolsDir "review"
New-Dir $toolsDir
New-Dir $logsDir
New-Dir $reviewDir

$ts = NowTs()
$logFile = Join-Path $logsDir ("diag_review_fail_{0}.log" -f $ts)
Write-Utf8NoBom $logFile ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))

function Log([string]$Line) {
  $t = (Get-Date).ToString("s")
  Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f $t, $Line) -Encoding utf8
}

$backupDir = Join-Path $toolsDir ("backup_diag_review_fail_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")
Log ("[INFO] BackupDir: {0}" -f $backupDir)

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
    return @{ ok=$false; code=124; title=$Title; out=""; err="TIMEOUT" }
  }

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $code = $p.ExitCode

  if ($stdout) { Log ("[OUT]`r`n" + $stdout.TrimEnd()) }
  if ($stderr) { Log ("[ERR]`r`n" + $stderr.TrimEnd()) }
  Log ("[EXIT] {0} => {1}" -f $Title, $code)

  return @{ ok=($code -eq 0); code=$code; title=$Title; out=$stdout; err=$stderr }
}

# -------- Evidence: package.json + local bins --------
$pkg = Join-Path $repo "package.json"
if (-not (Test-Path -LiteralPath $pkg -PathType Leaf)) {
  Log "[FATAL] Missing package.json"
  throw "Missing package.json"
}

$pkgRaw = Get-Content -LiteralPath $pkg -Raw
$pkgObj = $null
try { $pkgObj = $pkgRaw | ConvertFrom-Json } catch { $pkgObj = $null }

Log "[INFO] package.json loaded"
if ($pkgObj -and $pkgObj.scripts) {
  $scriptNames = $pkgObj.scripts.PSObject.Properties.Name
  Log ("[INFO] scripts: " + ($scriptNames -join ", "))
} else {
  Log "[WARN] scripts missing or unreadable"
}

$binDir = Join-Path $repo "node_modules\.bin"
$viteCmd = Join-Path $binDir "vite.cmd"
$vitestCmd = Join-Path $binDir "vitest.cmd"

function BinInfo([string]$p) {
  if (Test-Path -LiteralPath $p -PathType Leaf) {
    $fi = Get-Item -LiteralPath $p
    return ("FOUND ({0} bytes): {1}" -f $fi.Length, $p)
  }
  return ("MISSING: {0}" -f $p)
}

Log ("[INFO] " + (BinInfo $viteCmd))
Log ("[INFO] " + (BinInfo $vitestCmd))

# -------- Run verbose tests/build --------
# Force vitest to exit (no watch) + verbose output
$testCmd = "npm exec -- vitest run --watch=false --reporter=verbose"
$testRes = Invoke-CmdLine "Vitest (CI run)" $testCmd $repo $TimeoutSec

# Vite debug: enable DEBUG=vite:* via cmd.exe set
$buildCmd = "set DEBUG=vite:*&& npm exec -- vite build --debug"
$buildRes = Invoke-CmdLine "Vite build (debug)" $buildCmd $repo $TimeoutSec

# -------- Write summary MD --------
$fence = [string]::new([char]96, 3)
$mdPath = Join-Path $reviewDir ("DIAG_REVIEW_FAIL_{0}.md" -f $ts)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# DIAG REVIEW FAIL " + $ts)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("RepoRoot: " + $repo)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Evidence")
[void]$sb.AppendLine("- package.json: present")
[void]$sb.AppendLine("- node_modules\\.bin\\vitest.cmd: " + (BinInfo $vitestCmd))
[void]$sb.AppendLine("- node_modules\\.bin\\vite.cmd: " + (BinInfo $viteCmd))
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Commands")
[void]$sb.AppendLine("- Vitest: `" + $testCmd + "`")
[void]$sb.AppendLine("- Vite: `" + $buildCmd + "`")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Results (summary)")
[void]$sb.AppendLine(("- Vitest exit code: {0}" -f $testRes.code))
[void]$sb.AppendLine(("- Vite build exit code: {0}" -f $buildRes.code))
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Vitest stderr (tail)")
[void]$sb.AppendLine($fence)
$tailTest = ($testRes.err -split "`r?`n") | Select-Object -Last 120
[void]$sb.AppendLine(($tailTest -join "`r`n"))
[void]$sb.AppendLine($fence)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Vite stderr (tail)")
[void]$sb.AppendLine($fence)
$tailBuild = ($buildRes.err -split "`r?`n") | Select-Object -Last 160
[void]$sb.AppendLine(($tailBuild -join "`r`n"))
[void]$sb.AppendLine($fence)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Pointers")
[void]$sb.AppendLine("- Full log: " + $logFile)

Write-Utf8NoBom $mdPath $sb.ToString()
Log ("[PASS] Wrote diag report: {0}" -f $mdPath)

$exitCode = 0
if (-not $testRes.ok) { $exitCode = 2 }
if (-not $buildRes.ok) { $exitCode = 2 }

Log ("[DONE] EXIT CODE: {0}" -f $exitCode)
Write-Host ("[OK] Log: {0}" -f $logFile)
Write-Host ("[OK] Report: {0}" -f $mdPath)
exit $exitCode
