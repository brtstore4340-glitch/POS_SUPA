# FILE: WRITE_REVIEW_ONE_SHOT_SAFE_V4.ps1
# PURPOSE: Rewrite REVIEW_ONE_SHOT.ps1 to use npm exec for vitest/vite (avoids PATH/.bin issues), optionally repair deps via npm ci, then run.
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\WRITE_REVIEW_ONE_SHOT_SAFE_V4.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,
  [int]$TimeoutSec = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
trap { try { Write-Host ("[FATAL] " + $_.Exception.Message) } catch {}; exit 1 }

function New-Dir([string]$Path) { if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }
function Write-Utf8NoBom([string]$Path, [string]$Content) { $enc = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path, $Content, $enc) }
function Parse-Syntax([string]$FilePath) { $t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($FilePath,[ref]$t,[ref]$e); return $e }

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$toolsDir = Join-Path $repo "tools"
$logsDir  = Join-Path $toolsDir "logs"
New-Dir $toolsDir
New-Dir $logsDir

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$writerLog = Join-Path $logsDir ("write_review_one_shot_v4_{0}.log" -f $ts)
Write-Utf8NoBom $writerLog ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))
function WLog([string]$s){ Add-Content -LiteralPath $writerLog -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $s) -Encoding utf8 }

$backupDir = Join-Path $toolsDir ("backup_write_review_one_shot_v4_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")
WLog ("[INFO] BackupDir: {0}" -f $backupDir)

$target = Join-Path $repo "REVIEW_ONE_SHOT.ps1"
if (Test-Path -LiteralPath $target -PathType Leaf) {
  Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir "REVIEW_ONE_SHOT.ps1") -Force
  WLog "[INFO] Backed up existing REVIEW_ONE_SHOT.ps1"
}

$L = New-Object System.Collections.Generic.List[string]
function A([string]$s){ $script:L.Add($s) | Out-Null }

A '# FILE: REVIEW_ONE_SHOT.ps1'
A '# PURPOSE: One-shot project review (evidence + commands + report). No repo modifications.'
A 'param('
A '  [Parameter(Mandatory=$true)][string]$RepoRoot,'
A '  [int]$TreeLimit = 250,'
A '  [int]$TimeoutSec = 1800'
A ')'
A ''
A 'Set-StrictMode -Version Latest'
A '$ErrorActionPreference = "Stop"'
A 'trap { try { if ($script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value ("[FATAL] " + $_.Exception.Message) -Encoding utf8; Add-Content -LiteralPath $script:LogFile -Value "[FATAL] EXIT CODE: 1" -Encoding utf8 } } catch {}; exit 1 }'
A ''
A 'function New-Dir([string]$Path){ if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }'
A 'function Write-Utf8NoBom([string]$Path,[string]$Content){ $enc = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$Content,$enc) }'
A 'function Log([string]$Line){ $ts=(Get-Date).ToString("s"); Add-Content -LiteralPath $script:LogFile -Value ("[{0}] {1}" -f $ts,$Line) -Encoding utf8 }'
A 'function Assert-Dir([string]$Path,[string]$Name){ if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw ("Missing {0} directory: {1}" -f $Name,$Path) } }'
A 'function Get-RepoScripts([string]$PkgPath){ try{ $json=Get-Content -LiteralPath $PkgPath -Raw | ConvertFrom-Json; if ($null -ne $json.scripts){ return $json.scripts.PSObject.Properties.Name } }catch{}; return @() }'
A ''
A 'function Invoke-CmdLine([string]$Title,[string]$CmdLine,[string]$WorkDir,[int]$TimeoutSec){'
A '  Log ("[RUN] {0}" -f $Title)'
A '  Log ("[CMD] cmd.exe /c {0}" -f $CmdLine)'
A '  $pinfo=New-Object System.Diagnostics.ProcessStartInfo'
A '  $pinfo.FileName="cmd.exe"'
A '  $pinfo.WorkingDirectory=$WorkDir'
A '  $pinfo.RedirectStandardOutput=$true'
A '  $pinfo.RedirectStandardError=$true'
A '  $pinfo.UseShellExecute=$false'
A '  $pinfo.CreateNoWindow=$true'
A '  $pinfo.Arguments="/c " + $CmdLine'
A '  $p=New-Object System.Diagnostics.Process'
A '  $p.StartInfo=$pinfo'
A '  [void]$p.Start()'
A '  if (-not $p.WaitForExit($TimeoutSec*1000)){ try{ $p.Kill($true) }catch{}; Log ("[FAIL] Timeout after {0}s: {1}" -f $TimeoutSec,$Title); return @{ok=$false;code=124;title=$Title} }'
A '  $stdout=$p.StandardOutput.ReadToEnd()'
A '  $stderr=$p.StandardError.ReadToEnd()'
A '  $code=$p.ExitCode'
A '  if ($stdout){ Log ("[OUT] " + ($stdout.TrimEnd())) }'
A '  if ($stderr){ Log ("[ERR] " + ($stderr.TrimEnd())) }'
A '  Log ("[EXIT] {0} => {1}" -f $Title,$code)'
A '  return @{ok=($code -eq 0);code=$code;title=$Title}'
A '}'
A ''
A '# --- MAIN ---'
A '$repo=(Resolve-Path -LiteralPath $RepoRoot).Path'
A 'Assert-Dir $repo "RepoRoot"'
A '$toolsDir=Join-Path $repo "tools"'
A '$logsDir=Join-Path $toolsDir "logs"'
A '$reviewDir=Join-Path $toolsDir "review"'
A 'New-Dir $toolsDir; New-Dir $logsDir; New-Dir $reviewDir'
A '$ts=(Get-Date -Format "yyyyMMdd_HHmmss")'
A '$script:LogFile=Join-Path $logsDir ("review_one_shot_{0}.log" -f $ts)'
A 'Write-Utf8NoBom $script:LogFile ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo,(Get-Date).ToString("s"))'
A '$backupDir=Join-Path $toolsDir ("backup_review_one_shot_{0}" -f $ts)'
A 'New-Dir $backupDir'
A 'Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")'
A 'Log ("[INFO] BackupDir: {0}" -f $backupDir)'
A ''
A '$Fence=[string]::new([char]96,3)'
A '$evidence=New-Object System.Collections.Generic.List[string]'
A '$mustFix=New-Object System.Collections.Generic.List[string]'
A 'function Add-E([string]$s){ $evidence.Add($s) | Out-Null }'
A 'function Add-M([string]$s){ $mustFix.Add($s) | Out-Null }'
A ''
A '$pkg=Join-Path $repo "package.json"'
A 'if (-not (Test-Path -LiteralPath $pkg -PathType Leaf)){ Add-M "Missing package.json at repo root."; } else { Add-E "package.json found" }'
A '$scripts=@()'
A 'if (Test-Path -LiteralPath $pkg -PathType Leaf){ $scripts=Get-RepoScripts $pkg; Add-E ("package.json scripts: " + ($scripts -join ", ")) }'
A ''
A '# Ensure deps are sane: if vitest/vite missing in node_modules/.bin, run npm ci'
A '$binDir=Join-Path $repo "node_modules\.bin"'
A '$viteCmd=Join-Path $binDir "vite.cmd"'
A '$vitestCmd=Join-Path $binDir "vitest.cmd"'
A '$needCi=$false'
A 'if (-not (Test-Path -LiteralPath $viteCmd -PathType Leaf)) { $needCi=$true; Log "[WARN] Missing node_modules/.bin/vite.cmd" }'
A 'if (-not (Test-Path -LiteralPath $vitestCmd -PathType Leaf)) { $needCi=$true; Log "[WARN] Missing node_modules/.bin/vitest.cmd" }'
A 'if ($needCi) {'
A '  Log "[INFO] Repairing deps with: npm ci"'
A '  [void](Invoke-CmdLine "Install (npm ci)" "npm ci" $repo $TimeoutSec)'
A '} else { Log "[INFO] Local bins present; skipping npm ci." }'
A ''
A '$cmdResults=@()'
A 'if ($scripts -contains "test")  { $cmdResults += Invoke-CmdLine "Tests" "npm exec -- vitest" $repo $TimeoutSec }'
A 'if ($scripts -contains "build") { $cmdResults += Invoke-CmdLine "Build" "npm exec -- vite build" $repo $TimeoutSec }'
A ''
A '$hardFail=$false'
A 'foreach($r in $cmdResults){ if(-not $r.ok){ $hardFail=$true } }'
A 'if ($hardFail) { Add-M "One or more verify commands failed (see log for stderr)." }'
A ''
A '$tree=Get-ChildItem -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue |'
A '  Where-Object { $_.FullName -notmatch "\\node_modules\\" -and $_.FullName -notmatch "\\dist\\" -and $_.FullName -notmatch "\\build\\" -and $_.FullName -notmatch "\\.firebase\\" -and $_.FullName -notmatch "\\tools\\backup_" -and $_.FullName -notmatch "\\tools\\logs\\" } |'
A '  Select-Object -First $TreeLimit | ForEach-Object { $_.FullName.Substring($repo.Length).TrimStart("\") }'
A 'Add-E ("Repo tree captured: top " + $TreeLimit)'
A ''
A '$reportPath=Join-Path $reviewDir ("REVIEW_{0}.md" -f $ts)'
A '$rep=New-Object System.Text.StringBuilder'
A '[void]$rep.AppendLine("# PROJECT REVIEW " + $ts)'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("RepoRoot: " + $repo)'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Evidence")'
A 'foreach($e in $evidence){ [void]$rep.AppendLine("- " + $e) }'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Quick Tree (top " + $TreeLimit + ")")'
A '[void]$rep.AppendLine($Fence)'
A '[void]$rep.AppendLine(($tree -join "`r`n"))'
A '[void]$rep.AppendLine($Fence)'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Decision")'
A 'if ($mustFix.Count -gt 0 -or $hardFail){ [void]$rep.AppendLine("- Verdict: NEEDS FIX") } else { [void]$rep.AppendLine("- Verdict: PASS") }'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Findings Must-fix")'
A 'if ($mustFix.Count -eq 0){ [void]$rep.AppendLine("- (none)") } else { foreach($f in $mustFix){ [void]$rep.AppendLine("- " + $f) } }'
A '[void]$rep.AppendLine("")'
A '[void]$rep.AppendLine("## Command Results (summary)")'
A 'if ($cmdResults.Count -eq 0){ [void]$rep.AppendLine("- (no commands were run)") } else { $i=0; foreach($r in $cmdResults){ $i++; [void]$rep.AppendLine(("- #{0}: {1} code={2}" -f $i,$r.title,$r.code)) } }'
A ''
A 'Write-Utf8NoBom $reportPath $rep.ToString()'
A 'Log ("[PASS] Wrote report: {0}" -f $reportPath)'
A 'if ($mustFix.Count -gt 0 -or $hardFail){ Log "[DONE] EXIT CODE: 2"; exit 2 }'
A 'Log "[DONE] EXIT CODE: 0"; exit 0'

Write-Utf8NoBom $target (($L.ToArray()) -join "`r`n")
WLog ("[PASS] Wrote REVIEW_ONE_SHOT.ps1: {0}" -f $target)

$errs = Parse-Syntax $target
if ($errs -and $errs.Count -gt 0) {
  WLog ("[FATAL] Parser errors in generated file: {0}" -f $errs.Count)
  foreach ($e in $errs) { WLog ("[FATAL] {0} (Line {1}, Col {2})" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) }
  exit 2
}
WLog "[PASS] Parser check OK"

& pwsh -ExecutionPolicy Bypass -File $target -RepoRoot $repo -TimeoutSec $TimeoutSec
$rc = $LASTEXITCODE
WLog ("[EXIT] REVIEW_ONE_SHOT.ps1 => {0}" -f $rc)

Write-Host ("[OK] Writer log: {0}" -f $writerLog)
exit $rc
