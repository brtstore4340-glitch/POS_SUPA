# FILE: WRITE_REVIEW_ONE_SHOT_SAFE_V2.ps1
# PURPOSE: Rewrite REVIEW_ONE_SHOT.ps1 with reliable npm argument passing (.Arguments string), backup+logs, then run review.
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\WRITE_REVIEW_ONE_SHOT_SAFE_V2.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap { try { Write-Host ("[FATAL] " + $_.Exception.Message) } catch {}; exit 1 }

function New-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}
function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}
function Parse-Syntax([string]$FilePath) {
  $t = $null
  $e = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$t, [ref]$e)
  return $e
}

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$toolsDir = Join-Path $repo "tools"
$logsDir  = Join-Path $toolsDir "logs"
New-Dir $toolsDir
New-Dir $logsDir

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = Join-Path $logsDir ("write_review_one_shot_v2_{0}.log" -f $ts)
Write-Utf8NoBom $log ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))

function LogLine([string]$s) {
  Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $s) -Encoding utf8
}

$backupDir = Join-Path $toolsDir ("backup_write_review_one_shot_v2_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")
LogLine ("[INFO] BackupDir: {0}" -f $backupDir)

$target = Join-Path $repo "REVIEW_ONE_SHOT.ps1"
if (Test-Path -LiteralPath $target -PathType Leaf) {
  Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir "REVIEW_ONE_SHOT.ps1") -Force
  LogLine "[INFO] Backed up existing REVIEW_ONE_SHOT.ps1"
}

# Build REVIEW_ONE_SHOT.ps1 as lines (no risky here-string)
$L = New-Object System.Collections.Generic.List[string]
function A([string]$s){ $script:L.Add($s) | Out-Null }

A '# FILE: REVIEW_ONE_SHOT.ps1'
A '# PURPOSE: One-shot project review (evidence + commands + report). No repo modifications.'
A '# OUTPUTS: tools/logs/review_one_shot_*.log, tools/review/REVIEW_*.md, tools/LAST_BACKUP_DIR.txt'
A 'param('
A '  [Parameter(Mandatory=$true)]'
A '  [string]$RepoRoot,'
A '  [int]$MaxFileKB = 256,'
A '  [int]$TreeLimit = 250,'
A '  [int]$TimeoutSec = 1800'
A ')'
A ''
A 'Set-StrictMode -Version Latest'
A '$ErrorActionPreference = "Stop"'
A ''
A 'trap {'
A '  try {'
A '    if ($script:LogFile) {'
A '      Add-Content -LiteralPath $script:LogFile -Value ("[FATAL] " + $_.Exception.Message) -Encoding utf8'
A '      Add-Content -LiteralPath $script:LogFile -Value "[FATAL] EXIT CODE: 1" -Encoding utf8'
A '    }'
A '  } catch {}'
A '  exit 1'
A '}'
A ''
A 'function New-Dir([string]$Path) { if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }'
A 'function Write-Utf8NoBom([string]$Path, [string]$Content) { $enc = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path, $Content, $enc) }'
A 'function Log([string]$Line) { $ts = (Get-Date).ToString("s"); Add-Content -LiteralPath $script:LogFile -Value ("[{0}] {1}" -f $ts, $Line) -Encoding utf8 }'
A 'function Assert-Dir([string]$Path, [string]$Name) { if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw ("Missing {0} directory: {1}" -f $Name, $Path) } }'
A ''
A 'function Safe-ReadSnippet([string]$Path, [int]$MaxKB) {'
A '  try {'
A '    $fi = Get-Item -LiteralPath $Path -ErrorAction Stop'
A '    if ($fi.Length -gt ($MaxKB * 1024)) { return ("(skipped: {0} KB > cap {1} KB)" -f [int]([math]::Ceiling($fi.Length/1024)), $MaxKB) }'
A '    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop'
A '    if ($raw.Length -gt 6000) { return $raw.Substring(0,6000) + "`r`n... (truncated)" }'
A '    return $raw'
A '  } catch { return ("(read failed: {0})" -f $_.Exception.Message) }'
A '}'
A ''
A 'function Get-RepoScripts([string]$PkgPath) {'
A '  try { $json = Get-Content -LiteralPath $PkgPath -Raw | ConvertFrom-Json; if ($null -ne $json.scripts) { return $json.scripts.PSObject.Properties.Name } } catch {}'
A '  return @()'
A '}'
A ''
A 'function Invoke-Cmd([string]$Title, [string]$FilePath, [string[]]$Args, [string]$WorkDir, [int]$TimeoutSec) {'
A '  Log ("[RUN] {0}" -f $Title)'
A ''
A '  $argStr = ""'
A '  if ($Args -and $Args.Count -gt 0) {'
A '    $escaped = @()'
A '    foreach ($a in $Args) {'
A '      if ($a -match "\s|`"") { $escaped += (''"'' + ($a -replace ''"`"'',''\"'') + ''"'') } else { $escaped += $a }'
A '    }'
A '    $argStr = ($escaped -join " ")'
A '  }'
A ''
A '  Log ("[CMD] {0} {1}" -f $FilePath, $argStr)'
A ''
A '  $pinfo = New-Object System.Diagnostics.ProcessStartInfo'
A '  $pinfo.FileName = $FilePath'
A '  $pinfo.WorkingDirectory = $WorkDir'
A '  $pinfo.RedirectStandardOutput = $true'
A '  $pinfo.RedirectStandardError  = $true'
A '  $pinfo.UseShellExecute = $false'
A '  $pinfo.CreateNoWindow = $true'
A '  $pinfo.Arguments = $argStr'
A ''
A '  $p = New-Object System.Diagnostics.Process'
A '  $p.StartInfo = $pinfo'
A '  [void]$p.Start()'
A ''
A '  if (-not $p.WaitForExit($TimeoutSec * 1000)) {'
A '    try { $p.Kill($true) } catch {}'
A '    Log ("[FAIL] Timeout after {0}s: {1}" -f $TimeoutSec, $Title)'
A '    return @{ ok=$false; code=124; title=$Title }'
A '  }'
A ''
A '  $stdout = $p.StandardOutput.ReadToEnd()'
A '  $stderr = $p.StandardError.ReadToEnd()'
A '  $code = $p.ExitCode'
A ''
A '  if ($stdout) { Log ("[OUT] " + ($stdout.TrimEnd())) }'
A '  if ($stderr) { Log ("[ERR] " + ($stderr.TrimEnd())) }'
A '  Log ("[EXIT] {0} => {1}" -f $Title, $code)'
A ''
A '  return @{ ok=($code -eq 0); code=$code; title=$Title }'
A '}'
A ''
A '# --- MAIN ---'
A '$repo = (Resolve-Path -LiteralPath $RepoRoot).Path'
A 'Assert-Dir $repo "RepoRoot"'
A ''
A '$toolsDir  = Join-Path $repo "tools"'
A '$logsDir   = Join-Path $toolsDir "logs"'
A '$reviewDir = Join-Path $toolsDir "review"'
A 'New-Dir $toolsDir; New-Dir $logsDir; New-Dir $reviewDir'
A ''
A '$ts = (Get-Date -Format "yyyyMMdd_HHmmss")'
A '$script:LogFile = Join-Path $logsDir ("review_one_shot_{0}.log" -f $ts)'
A 'Write-Utf8NoBom $script:LogFile ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))'
A ''
A '$backupDir = Join-Path $toolsDir ("backup_review_one_shot_{0}" -f $ts)'
A 'New-Dir $backupDir'
A 'Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")'
A 'Log ("[INFO] BackupDir: {0}" -f $backupDir)'
A ''
A '$Fence = [string]::new([char]96, 3)'
A ''
A '$evidence = New-Object System.Collections.Generic.List[string]'
A '$mustFix  = New-Object System.Collections.Generic.List[string]'
A '$nice     = New-Object System.Collections.Generic.List[string]'
A 'function Add-E([string]$s){ $evidence.Add($s) | Out-Null }'
A 'function Add-M([string]$s){ $mustFix.Add($s) | Out-Null }'
A 'function Add-N([string]$s){ $nice.Add($s) | Out-Null }'
A ''
A '$pkg = Join-Path $repo "package.json"'
A 'if (-not (Test-Path -LiteralPath $pkg -PathType Leaf)) { Add-M "Missing package.json at repo root (cannot run verify build)." } else { Add-E "package.json found" }'
A ''
A '$rules = Join-Path $repo "firestore.rules"'
A 'if (Test-Path -LiteralPath $rules -PathType Leaf) {'
A '  $txt = Get-Content -LiteralPath $rules -Raw -ErrorAction SilentlyContinue'
A '  Add-E "firestore.rules scanned for allow if true"'
A '  if ($txt -and ($txt -match "allow\s+read\s*:\s*if\s*true|allow\s+write\s*:\s*if\s*true")) { Add-M "firestore.rules contains allow read/write if true (deny-by-default violated)." }'
A '}'
A ''
A '$tree = Get-ChildItem -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue |'
A '  Where-Object {'
A '    $_.FullName -notmatch "\\node_modules\\" -and'
A '    $_.FullName -notmatch "\\dist\\" -and'
A '    $_.FullName -notmatch "\\build\\" -and'
A '    $_.FullName -notmatch "\\.firebase\\" -and'
A '    $_.FullName -notmatch "\\tools\\backup_" -and'
A '    $_.FullName -notmatch "\\tools\\logs\\"'
A '  } | Select-Object -First $TreeLimit | ForEach-Object { $_.FullName.Substring($repo.Length).TrimStart("\") }'
A 'Add-E ("Repo tree captured: top " + $TreeLimit)'
A ''
A '$cmdResults = @()'
A 'if (Test-Path -LiteralPath $pkg -PathType Leaf) {'
A '  $scripts = Get-RepoScripts $pkg'
A '  Add-E ("package.json scripts: " + ($scripts -join ", "))'
A '  $pm = "npm"'
A '  if (Test-Path -LiteralPath (Join-Path $repo "pnpm-lock.yaml")) { $pm = "pnpm" }'
A '  elseif (Test-Path -LiteralPath (Join-Path $repo "yarn.lock"))  { $pm = "yarn" }'
A '  Add-E ("Package manager inferred: " + $pm)'
A ''
A '  $nm = Join-Path $repo "node_modules"'
A '  if (-not (Test-Path -LiteralPath $nm -PathType Container)) {'
A '    if ($pm -eq "npm")      { $cmdResults += Invoke-Cmd "Install (npm ci)" "npm"  @("ci") $repo $TimeoutSec }'
A '    elseif ($pm -eq "pnpm") { $cmdResults += Invoke-Cmd "Install (pnpm i)" "pnpm" @("i","--frozen-lockfile") $repo $TimeoutSec }'
A '    else                    { $cmdResults += Invoke-Cmd "Install (yarn install)" "yarn" @("install","--frozen-lockfile") $repo $TimeoutSec }'
A '  } else { Log "[INFO] node_modules exists; skipping install." }'
A ''
A '  if ($scripts -contains "test")  { $cmdResults += Invoke-Cmd "Tests" "npm" @("run","test")  $repo $TimeoutSec } else { Add-N "No script ''test'' in package.json." }'
A '  if ($scripts -contains "build") { $cmdResults += Invoke-Cmd "Build" "npm" @("run","build") $repo $TimeoutSec } else { Add-N "No script ''build'' in package.json." }'
A '}'
A ''
A '$hardFail = $false'
A 'foreach ($r in $cmdResults) { if (-not $r.ok) { $hardFail = $true } }'
A 'if ($hardFail) { Add-M "One or more verify commands failed (see tools/logs for exit codes and stderr)." }'
A ''
A '$reportPath = Join-Path $reviewDir ("REVIEW_{0}.md" -f $ts)'
A '$rep = New-Object System.Text.StringBuilder'
A '[void]$rep.AppendLine("# PROJECT REVIEW " + $ts)'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("RepoRoot: " + $repo)'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Evidence")'
A 'foreach ($e in $evidence) { [void]$rep.AppendLine("- " + $e) }'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Quick Tree (top " + $TreeLimit + ")")'
A '[void]$rep.AppendLine($Fence)'
A '[void]$rep.AppendLine(($tree -join "`r`n"))'
A '[void]$rep.AppendLine($Fence)'
A ''
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Decision")'
A 'if ($mustFix.Count -gt 0 -or $hardFail) { [void]$rep.AppendLine("- Verdict: NEEDS FIX") } else { [void]$rep.AppendLine("- Verdict: PASS") }'
A ''
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Findings Must-fix")'
A 'if ($mustFix.Count -eq 0) { [void]$rep.AppendLine("- (none)") } else { foreach ($f in $mustFix) { [void]$rep.AppendLine("- " + $f) } }'
A ''
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Findings Nice-to-have")'
A 'if ($nice.Count -eq 0) { [void]$rep.AppendLine("- (none)") } else { foreach ($f in $nice) { [void]$rep.AppendLine("- " + $f) } }'
A ''
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Command Results (summary)")'
A 'if ($cmdResults.Count -eq 0) { [void]$rep.AppendLine("- (no commands were run)") } else { $i=0; foreach ($r in $cmdResults) { $i++; [void]$rep.AppendLine(("- #{0}: {1} code={2}" -f $i, $r.title, $r.code)) } }'
A ''
A 'Write-Utf8NoBom $reportPath $rep.ToString()'
A 'Log ("[PASS] Wrote report: {0}" -f $reportPath)'
A 'if ($mustFix.Count -gt 0 -or $hardFail) { Log "[DONE] EXIT CODE: 2"; exit 2 }'
A 'Log "[DONE] EXIT CODE: 0"; exit 0'

Write-Utf8NoBom $target (($L.ToArray()) -join "`r`n")
LogLine ("[PASS] Wrote REVIEW_ONE_SHOT.ps1: {0}" -f $target)

$errs = Parse-Syntax $target
if ($errs -and $errs.Count -gt 0) {
  LogLine ("[FATAL] Parser errors in generated file: {0}" -f $errs.Count)
  foreach ($e in $errs) { LogLine ("[FATAL] {0} (Line {1}, Col {2})" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) }
  exit 2
}
LogLine "[PASS] Parser check OK"

& pwsh -ExecutionPolicy Bypass -File $target -RepoRoot $repo
$rc = $LASTEXITCODE
LogLine ("[EXIT] REVIEW_ONE_SHOT.ps1 => {0}" -f $rc)

Write-Host ("[OK] Writer log: {0}" -f $log)
exit $rc
