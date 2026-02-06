# FILE: FIX_REVIEW_PROJECT_FULL_FINAL.ps1
# PURPOSE: One-shot FINAL fix. Rewrite REVIEW_PROJECT_FULL.ps1 (parser-safe) + backup + logs + parse-check + run review.
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\FIX_REVIEW_PROJECT_FULL_FINAL.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

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
$log = Join-Path $logsDir ("fix_review_final_{0}.log" -f $ts)
Write-Utf8NoBom $log ("[INFO] RepoRoot: {0}`n[INFO] Start: {1}`n" -f $repo, (Get-Date).ToString("s"))

$backupDir = Join-Path $toolsDir ("backup_fix_review_final_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`n")
LogLine $log ("[INFO] BackupDir: {0}" -f $backupDir)

$target = Join-Path $repo "REVIEW_PROJECT_FULL.ps1"
if (Test-Path -LiteralPath $target -PathType Leaf) {
  Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir "REVIEW_PROJECT_FULL.ps1") -Force
  LogLine $log "[INFO] Backed up existing REVIEW_PROJECT_FULL.ps1"
} else {
  LogLine $log "[WARN] REVIEW_PROJECT_FULL.ps1 not found; will create new"
}

# Build REVIEW_PROJECT_FULL.ps1 as array lines (no here-string, no backtick char, no em dash)
$L = New-Object System.Collections.Generic.List[string]
function A([string]$s) { $script:L.Add($s) | Out-Null }

A '# FILE: REVIEW_PROJECT_FULL.ps1'
A '# PURPOSE: Full project review runner (evidence + commands + report). No code modifications.'
A '# USAGE:'
A '#   pwsh -ExecutionPolicy Bypass -File .\REVIEW_PROJECT_FULL.ps1 -RepoRoot "D:\path\to\repo"'
A '#   pwsh -ExecutionPolicy Bypass -File .\REVIEW_PROJECT_FULL.ps1 -RepoRoot "D:\path\to\repo" -MaxFileKB 256 -TimeoutSec 1800'
A ''
A 'param('
A '  [Parameter(Mandatory=$true)]'
A '  [string]$RepoRoot,'
A ''
A '  [int]$MaxFileKB = 256,'
A '  [int]$MaxFiles  = 2500,'
A '  [int]$TimeoutSec = 1800'
A ')'
A ''
A 'Set-StrictMode -Version Latest'
A '$ErrorActionPreference = "Stop"'
A ''
A 'trap {'
A '  try {'
A '    $msg = $_.Exception.Message'
A '    if ($script:LogFile) {'
A '      Add-Content -LiteralPath $script:LogFile -Value ("[FATAL] {0}" -f $msg) -Encoding utf8'
A '      Add-Content -LiteralPath $script:LogFile -Value ("[FATAL] EXIT CODE: 1") -Encoding utf8'
A '    }'
A '  } catch {}'
A '  exit 1'
A '}'
A ''
A 'function New-Dir([string]$Path) {'
A '  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }'
A '}'
A ''
A 'function Write-Utf8NoBom([string]$Path, [string]$Content) {'
A '  $enc = New-Object System.Text.UTF8Encoding($false)'
A '  [System.IO.File]::WriteAllText($Path, $Content, $enc)'
A '}'
A ''
A 'function NowTs() { (Get-Date).ToString("yyyyMMdd_HHmmss") }'
A ''
A 'function Log([string]$Line) {'
A '  $ts = (Get-Date).ToString("s")'
A '  Add-Content -LiteralPath $script:LogFile -Value ("[{0}] {1}" -f $ts, $Line) -Encoding utf8'
A '}'
A ''
A 'function Assert-Dir([string]$Path, [string]$Name) {'
A '  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {'
A '    throw ("Missing {0} directory: {1}" -f $Name, $Path)'
A '  }'
A '}'
A ''
A 'function Backup-IfExists([string]$FilePath, [string]$BackupDir) {'
A '  if (Test-Path -LiteralPath $FilePath -PathType Leaf) {'
A '    Copy-Item -LiteralPath $FilePath -Destination (Join-Path $BackupDir (Split-Path $FilePath -Leaf)) -Force'
A '    Log ("[INFO] Backed up: {0}" -f $FilePath)'
A '  }'
A '}'
A ''
A 'function Get-RepoScripts([string]$PkgPath) {'
A '  try {'
A '    $json = Get-Content -LiteralPath $PkgPath -Raw | ConvertFrom-Json'
A '    if ($null -ne $json.scripts) { return $json.scripts.PSObject.Properties.Name }'
A '  } catch {}'
A '  return @()'
A '}'
A ''
A 'function Invoke-Cmd([string]$Title, [string]$FilePath, [string[]]$Args, [string]$WorkDir, [int]$TimeoutSec) {'
A '  Log ("[RUN] {0}" -f $Title)'
A '  Log ("[CMD] {0} {1}" -f $FilePath, ($Args -join " "))'
A ''
A '  $pinfo = New-Object System.Diagnostics.ProcessStartInfo'
A '  $pinfo.FileName = $FilePath'
A '  $pinfo.WorkingDirectory = $WorkDir'
A '  $pinfo.RedirectStandardOutput = $true'
A '  $pinfo.RedirectStandardError  = $true'
A '  $pinfo.UseShellExecute = $false'
A '  $pinfo.CreateNoWindow = $true'
A '  foreach ($a in $Args) { [void]$pinfo.ArgumentList.Add($a) }'
A ''
A '  $p = New-Object System.Diagnostics.Process'
A '  $p.StartInfo = $pinfo'
A '  [void]$p.Start()'
A ''
A '  if (-not $p.WaitForExit($TimeoutSec * 1000)) {'
A '    try { $p.Kill($true) } catch {}'
A '    Log ("[FAIL] Timeout after {0}s: {1}" -f $TimeoutSec, $Title)'
A '    return @{ ok=$false; code=124; stdout=""; stderr="TIMEOUT" }'
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
A '  return @{ ok=($code -eq 0); code=$code; stdout=$stdout; stderr=$stderr }'
A '}'
A ''
A 'function Safe-ReadSnippet([string]$Path, [int]$MaxKB) {'
A '  try {'
A '    $fi = Get-Item -LiteralPath $Path -ErrorAction Stop'
A '    if ($fi.Length -gt ($MaxKB * 1024)) {'
A '      return ("(skipped: {0} KB > cap {1} KB)" -f [int]([math]::Ceiling($fi.Length/1024)), $MaxKB)'
A '    }'
A '    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop'
A '    if ($raw.Length -gt 6000) { return $raw.Substring(0,6000) + "`n... (truncated)" }'
A '    return $raw'
A '  } catch {'
A '    return ("(read failed: {0})" -f $_.Exception.Message)'
A '  }'
A '}'
A ''
A '# --- main ---'
A '$repo = (Resolve-Path -LiteralPath $RepoRoot).Path'
A 'Assert-Dir $repo "RepoRoot"'
A ''
A '$toolsDir  = Join-Path $repo "tools"'
A '$logsDir   = Join-Path $toolsDir "logs"'
A '$reviewDir = Join-Path $toolsDir "review"'
A '$ctxDir    = Join-Path $toolsDir "context"'
A 'New-Dir $toolsDir'
A 'New-Dir $logsDir'
A 'New-Dir $reviewDir'
A 'New-Dir $ctxDir'
A ''
A '$ts = NowTs'
A '$script:LogFile = Join-Path $logsDir ("review_full_{0}.log" -f $ts)'
A 'Write-Utf8NoBom $script:LogFile ("[INFO] RepoRoot: {0}`n[INFO] Start: {1}`n" -f $repo, (Get-Date).ToString("s"))'
A ''
A '$backupDir = Join-Path $toolsDir ("backup_review_full_{0}" -f $ts)'
A 'New-Dir $backupDir'
A 'Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`n")'
A 'Log ("[INFO] BackupDir: {0}" -f $backupDir)'
A ''
A '$reportPath = Join-Path $reviewDir ("REVIEW_{0}.md" -f $ts)'
A '$ctxPath    = Join-Path $ctxDir ("CONTEXT_PACK_{0}.md" -f $ts)'
A 'Backup-IfExists $reportPath $backupDir'
A 'Backup-IfExists $ctxPath $backupDir'
A ''
A '# IMPORTANT: fence uses char 96 to avoid parser issues with backtick in source'
A '$Fence = (([char]96) * 3)'
A ''
A '# Context pack'
A '$ctx = New-Object System.Text.StringBuilder'
A '[void]$ctx.AppendLine("# CONTEXT_PACK - " + $ts)'
A '[void]$ctx.AppendLine("")'
A '[void]$ctx.AppendLine("RepoRoot: " + $repo)'
A '[void]$ctx.AppendLine("Generated: " + (Get-Date).ToString("s"))'
A '[void]$ctx.AppendLine("")'
A '[void]$ctx.AppendLine("## Key Files (snippets, capped)")'
A '[void]$ctx.AppendLine("")'
A ''
A '$keyList = @("package.json","firebase.json","firestore.rules","tsconfig.json",".firebaserc")'
A 'foreach ($k in $keyList) {'
A '  $p = Join-Path $repo $k'
A '  if (Test-Path -LiteralPath $p -PathType Leaf) {'
A '    [void]$ctx.AppendLine("### " + $k)'
A '    [void]$ctx.AppendLine($Fence)'
A '    [void]$ctx.AppendLine((Safe-ReadSnippet $p $MaxFileKB))'
A '    [void]$ctx.AppendLine($Fence)'
A '    [void]$ctx.AppendLine("")'
A '  }'
A '}'
A ''
A '$dirs = @("docs","plans","src","functions","tools")'
A 'foreach ($d in $dirs) {'
A '  $dp = Join-Path $repo $d'
A '  if (Test-Path -LiteralPath $dp -PathType Container) {'
A '    [void]$ctx.AppendLine("## Tree: " + $d + " (top 200)")'
A '    [void]$ctx.AppendLine($Fence)'
A '    $tree = Get-ChildItem -LiteralPath $dp -Recurse -Force -ErrorAction SilentlyContinue |'
A '      Where-Object { $_.FullName -notmatch "\\\\node_modules\\\\" -and $_.FullName -notmatch "\\\\dist\\\\" -and $_.FullName -notmatch "\\\\build\\\\" } |'
A '      Select-Object -First 200 |'
A '      ForEach-Object { $_.FullName.Substring($repo.Length).TrimStart("\") }'
A '    [void]$ctx.AppendLine(($tree -join "`n"))'
A '    [void]$ctx.AppendLine($Fence)'
A '    [void]$ctx.AppendLine("")'
A '  }'
A '}'
A ''
A 'Write-Utf8NoBom $ctxPath $ctx.ToString()'
A 'Log ("[PASS] Wrote context pack: {0}" -f $ctxPath)'
A ''
A '# Findings'
A '$findingsMust   = New-Object System.Collections.Generic.List[string]'
A '$findingsShould = New-Object System.Collections.Generic.List[string]'
A '$findingsNice   = New-Object System.Collections.Generic.List[string]'
A '$evidence       = New-Object System.Collections.Generic.List[string]'
A 'function Add-Evidence([string]$Item) { $evidence.Add($Item) | Out-Null }'
A 'function Add-Must([string]$Item)     { $findingsMust.Add($Item) | Out-Null }'
A 'function Add-Should([string]$Item)   { $findingsShould.Add($Item) | Out-Null }'
A 'function Add-Nice([string]$Item)     { $findingsNice.Add($Item) | Out-Null }'
A ''
A '$pkg = Join-Path $repo "package.json"'
A 'if (Test-Path -LiteralPath $pkg) { Add-Evidence "package.json (scripts inspected)" } else { Add-Must "Missing package.json at repo root (cannot verify build reliably)" }'
A ''
A '$rules = Join-Path $repo "firestore.rules"'
A 'if (Test-Path -LiteralPath $rules) {'
A '  Add-Evidence "firestore.rules (deny-by-default quick scan)"'
A '  $txt = (Get-Content -LiteralPath $rules -Raw -ErrorAction SilentlyContinue)'
A '  if ($txt -and ($txt -match "allow\s+read\s*:\s*if\s*true|allow\s+write\s*:\s*if\s*true")) {'
A '    Add-Must "firestore.rules contains allow read/write if true (deny-by-default violated)"'
A '  }'
A '} else {'
A '  Add-Should "No firestore.rules found at repo root (if using Firestore, add deny-by-default rules)"'
A '}'
A ''
A '$envFiles = Get-ChildItem -LiteralPath $repo -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^\.env(\.|$)" } | Select-Object -First 20'
A 'if ($envFiles.Count -gt 0) {'
A '  Add-Evidence ("env files detected: " + (($envFiles | ForEach-Object { $_.Name }) -join ", "))'
A '  Add-Should "Confirm .env* are gitignored and secrets are not committed"'
A '}'
A ''
A '# Commands'
A '$cmdResults = @()'
A 'if (Test-Path -LiteralPath $pkg) {'
A '  $scripts = Get-RepoScripts $pkg'
A '  Log ("[INFO] package.json scripts: {0}" -f ($scripts -join ", "))'
A ''
A '  $pm = "npm"'
A '  if (Test-Path -LiteralPath (Join-Path $repo "pnpm-lock.yaml")) { $pm = "pnpm" }'
A '  elseif (Test-Path -LiteralPath (Join-Path $repo "yarn.lock"))  { $pm = "yarn" }'
A '  elseif (Test-Path -LiteralPath (Join-Path $repo "package-lock.json")) { $pm = "npm" }'
A '  Add-Evidence ("Package manager inferred: " + $pm)'
A ''
A '  $nm = Join-Path $repo "node_modules"'
A '  if (-not (Test-Path -LiteralPath $nm -PathType Container)) {'
A '    if ($pm -eq "npm")      { $cmdResults += (Invoke-Cmd "Install (npm ci)" "npm"  @("ci") $repo $TimeoutSec) }'
A '    elseif ($pm -eq "pnpm") { $cmdResults += (Invoke-Cmd "Install (pnpm i)" "pnpm" @("i","--frozen-lockfile") $repo $TimeoutSec) }'
A '    else                    { $cmdResults += (Invoke-Cmd "Install (yarn install)" "yarn" @("install","--frozen-lockfile") $repo $TimeoutSec) }'
A '  } else {'
A '    Log "[INFO] node_modules exists; skipping install."'
A '  }'
A ''
A '  $want = @('
A '    @{name="lint";      title="Lint"},'
A '    @{name="typecheck"; title="Typecheck"},'
A '    @{name="test";      title="Tests"},'
A '    @{name="build";     title="Build"}'
A '  )'
A '  foreach ($w in $want) {'
A '    if ($scripts -contains $w.name) {'
A '      if ($pm -eq "npm")      { $cmdResults += (Invoke-Cmd $w.title "npm"  @("run",$w.name) $repo $TimeoutSec) }'
A '      elseif ($pm -eq "pnpm") { $cmdResults += (Invoke-Cmd $w.title "pnpm" @("run",$w.name) $repo $TimeoutSec) }'
A '      else                    { $cmdResults += (Invoke-Cmd $w.title "yarn" @($w.name) $repo $TimeoutSec) }'
A '    } else {'
A '      Add-Nice ("No script ''" + $w.name + "'' in package.json (ok if intentional)")'
A '    }'
A '  }'
A '}'
A ''
A '$hardFail = $false'
A 'foreach ($r in $cmdResults) { if (-not $r.ok) { $hardFail = $true } }'
A 'if ($hardFail) { Add-Must "One or more verify commands failed (see log + report for exit codes)" }'
A ''
A '# Report'
A '$rep = New-Object System.Text.StringBuilder'
A '[void]$rep.AppendLine("# PROJECT REVIEW - " + $ts)'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("RepoRoot: " + $repo)'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Evidence")'
A 'foreach ($e in $evidence) { [void]$rep.AppendLine("- " + $e) }'
A '[void]$rep.AppendLine("- Context pack: tools/context/" + (Split-Path $ctxPath -Leaf))'
A '[void]$rep.AppendLine("- Log: tools/logs/" + (Split-Path $script:LogFile -Leaf))'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Decision")'
A 'if ($findingsMust.Count -gt 0 -or $hardFail) { [void]$rep.AppendLine("- Verdict: NEEDS FIX") } else { [void]$rep.AppendLine("- Verdict: PASS") }'
A ''
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Findings - Must-fix")'
A 'if ($findingsMust.Count -eq 0) { [void]$rep.AppendLine("- (none)") } else { foreach ($f in $findingsMust) { [void]$rep.AppendLine("- " + $f) } }'
A ''
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Findings - Should-fix")'
A 'if ($findingsShould.Count -eq 0) { [void]$rep.AppendLine("- (none)") } else { foreach ($f in $findingsShould) { [void]$rep.AppendLine("- " + $f) } }'
A ''
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Findings - Nice-to-have")'
A 'if ($findingsNice.Count -eq 0) { [void]$rep.AppendLine("- (none)") } else { foreach ($f in $findingsNice) { [void]$rep.AppendLine("- " + $f) } }'
A ''
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Command Results (summary)")'
A 'if ($cmdResults.Count -eq 0) { [void]$rep.AppendLine("- (no commands were run)") } else { $i=0; foreach ($r in $cmdResults) { $i++; [void]$rep.AppendLine(("- #{0}: ok={1} code={2}" -f $i, $r.ok, $r.code)) } }'
A ''
A 'Write-Utf8NoBom $reportPath $rep.ToString()'
A 'Log ("[PASS] Wrote report: {0}" -f $reportPath)'
A ''
A 'if ($findingsMust.Count -gt 0 -or $hardFail) { Log "[DONE] EXIT CODE: 2"; exit 2 }'
A 'Log "[DONE] EXIT CODE: 0"'
A 'exit 0'

$content = ($L.ToArray() -join "`r`n")
Write-Utf8NoBom $target $content
LogLine $log ("[PASS] Rewrote REVIEW_PROJECT_FULL.ps1: {0}" -f $target)

# Parse-check generated file
$errs = Parse-Syntax $target
if ($errs -and $errs.Count -gt 0) {
  LogLine $log ("[FATAL] Parser errors in generated file: {0}" -f $errs.Count)
  foreach ($e in $errs) { LogLine $log ("[FATAL] {0} (Line {1}, Col {2})" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) }
  LogLine $log "[FATAL] EXIT CODE: 2"
  exit 2
}
LogLine $log "[PASS] Parser check OK"

# Run review now
LogLine $log "[RUN] Executing REVIEW_PROJECT_FULL.ps1"
& pwsh -ExecutionPolicy Bypass -File $target -RepoRoot $repo
$rc = $LASTEXITCODE
LogLine $log ("[EXIT] REVIEW_PROJECT_FULL.ps1 => {0}" -f $rc)

# Show latest artifacts paths
$reviewDir = Join-Path $repo "tools\review"
$ctxDir    = Join-Path $repo "tools\context"
$latestReport = $null
$latestCtx    = $null
if (Test-Path -LiteralPath $reviewDir) {
  $latestReport = Get-ChildItem -LiteralPath $reviewDir -Filter "REVIEW_*.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
}
if (Test-Path -LiteralPath $ctxDir) {
  $latestCtx = Get-ChildItem -LiteralPath $ctxDir -Filter "CONTEXT_PACK_*.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
}

if ($latestReport) { LogLine $log ("[INFO] Latest report: {0}" -f $latestReport.FullName) }
if ($latestCtx)    { LogLine $log ("[INFO] Latest context: {0}" -f $latestCtx.FullName) }

Write-Host ("[OK] Fix log: {0}" -f $log)
if ($latestReport) { Write-Host ("[OK] Report:  {0}" -f $latestReport.FullName) }
if ($latestCtx)    { Write-Host ("[OK] Context: {0}" -f $latestCtx.FullName) }
Write-Host ("[OK] Review exit code: {0}" -f $rc)

exit $rc
