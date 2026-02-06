# FILE: RUN_DIAG_REVIEW_FAIL_SAFE.ps1
# PURPOSE: Safe runner for DIAG_REVIEW_FAIL_ONE_SHOT.ps1 (backup + parse-check; if parser error, rewrite minimal known-good diag script, then run).
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\RUN_DIAG_REVIEW_FAIL_SAFE.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,
  [int]$TimeoutSec = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
trap { try { Write-Host ("[FATAL] " + $_.Exception.Message) } catch {}; exit 1 }

function New-Dir([string]$Path){ if(-not (Test-Path -LiteralPath $Path)){ New-Item -ItemType Directory -Path $Path -Force | Out-Null } }
function Write-Utf8NoBom([string]$Path,[string]$Content){ $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$Content,$enc) }
function Parse-Syntax([string]$FilePath){ $t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($FilePath,[ref]$t,[ref]$e); return $e }

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$tools = Join-Path $repo "tools"
$logs  = Join-Path $tools "logs"
New-Dir $tools
New-Dir $logs

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$log = Join-Path $logs ("run_diag_review_fail_safe_{0}.log" -f $ts)
Write-Utf8NoBom $log ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))
function LogLine([string]$s){ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $s) -Encoding utf8 }

$backupDir = Join-Path $tools ("backup_run_diag_review_fail_safe_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $tools "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")
LogLine ("[INFO] BackupDir: {0}" -f $backupDir)

$diag = Join-Path $repo "DIAG_REVIEW_FAIL_ONE_SHOT.ps1"
if (-not (Test-Path -LiteralPath $diag -PathType Leaf)) { throw ("Missing file: {0}" -f $diag) }

Copy-Item -LiteralPath $diag -Destination (Join-Path $backupDir "DIAG_REVIEW_FAIL_ONE_SHOT.ps1") -Force
LogLine "[INFO] Backed up DIAG_REVIEW_FAIL_ONE_SHOT.ps1"

$errs = Parse-Syntax $diag
if ($errs -and $errs.Count -gt 0) {
  LogLine ("[WARN] Parser errors detected: {0} -> rewriting to known-good minimal diag script" -f $errs.Count)

  $L = New-Object System.Collections.Generic.List[string]
  function A([string]$s){ $script:L.Add($s) | Out-Null }

  A 'param([Parameter(Mandatory=$true)][string]$RepoRoot,[int]$TimeoutSec=1800)'
  A 'Set-StrictMode -Version Latest'
  A '$ErrorActionPreference="Stop"'
  A 'trap { try { Write-Host ("[FATAL] " + $_.Exception.Message) } catch {}; exit 1 }'
  A 'function New-Dir([string]$Path){ if(-not (Test-Path -LiteralPath $Path)){ New-Item -ItemType Directory -Path $Path -Force | Out-Null } }'
  A 'function Write-Utf8NoBom([string]$Path,[string]$Content){ $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$Content,$enc) }'
  A 'function Assert-Dir([string]$Path,[string]$Name){ if(-not (Test-Path -LiteralPath $Path -PathType Container)){ throw ("Missing {0} directory: {1}" -f $Name,$Path) } }'
  A 'function Log([string]$Line){ $t=(Get-Date).ToString("s"); Add-Content -LiteralPath $script:LogFile -Value ("[{0}] {1}" -f $t,$Line) -Encoding utf8 }'
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
  A '  if(-not $p.WaitForExit($TimeoutSec*1000)){ try{ $p.Kill($true) }catch{}; Log ("[FAIL] Timeout after {0}s: {1}" -f $TimeoutSec,$Title); return @{ok=$false;code=124;title=$Title;out="";err="TIMEOUT"} }'
  A '  $stdout=$p.StandardOutput.ReadToEnd()'
  A '  $stderr=$p.StandardError.ReadToEnd()'
  A '  $code=$p.ExitCode'
  A '  if($stdout){ Log ("[OUT]`r`n" + $stdout.TrimEnd()) }'
  A '  if($stderr){ Log ("[ERR]`r`n" + $stderr.TrimEnd()) }'
  A '  Log ("[EXIT] {0} => {1}" -f $Title,$code)'
  A '  return @{ok=($code -eq 0);code=$code;title=$Title;out=$stdout;err=$stderr}'
  A '}'
  A ''
  A '$repo=(Resolve-Path -LiteralPath $RepoRoot).Path'
  A 'Assert-Dir $repo "RepoRoot"'
  A '$tools=Join-Path $repo "tools"'
  A '$logs=Join-Path $tools "logs"'
  A '$review=Join-Path $tools "review"'
  A 'New-Dir $tools; New-Dir $logs; New-Dir $review'
  A '$ts = Get-Date -Format "yyyyMMdd_HHmmss"'
  A '$script:LogFile=Join-Path $logs ("diag_review_fail_{0}.log" -f $ts)'
  A 'Write-Utf8NoBom $script:LogFile ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo,(Get-Date).ToString("s"))'
  A ''
  A '$bin=Join-Path $repo "node_modules\.bin"'
  A '$vitest=Join-Path $bin "vitest.cmd"'
  A '$vite=Join-Path $bin "vite.cmd"'
  A 'function BinInfo([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $fi=Get-Item -LiteralPath $p; return ("FOUND ({0} bytes): {1}" -f $fi.Length,$p) } return ("MISSING: {0}" -f $p) }'
  A 'Log ("[INFO] " + (BinInfo $vitest))'
  A 'Log ("[INFO] " + (BinInfo $vite))'
  A ''
  A '$testRes=Invoke-CmdLine "Vitest (CI run)" "npm exec -- vitest run --watch=false --reporter=verbose" $repo $TimeoutSec'
  A '$buildRes=Invoke-CmdLine "Vite build (debug)" "set DEBUG=vite:*&& npm exec -- vite build --debug" $repo $TimeoutSec'
  A ''
  A '$fence=[string]::new([char]96,3)'
  A '$md=Join-Path $review ("DIAG_REVIEW_FAIL_{0}.md" -f $ts)'
  A '$sb=New-Object System.Text.StringBuilder'
  A '[void]$sb.AppendLine("# DIAG REVIEW FAIL " + $ts)'
  A '[void]$sb.AppendLine("")'
  A '[void]$sb.AppendLine("RepoRoot: " + $repo)'
  A '[void]$sb.AppendLine("")'
  A '[void]$sb.AppendLine("## Results (summary)")'
  A '[void]$sb.AppendLine(("- Vitest exit code: {0}" -f $testRes.code))'
  A '[void]$sb.AppendLine(("- Vite exit code: {0}" -f $buildRes.code))'
  A '[void]$sb.AppendLine("")'
  A '[void]$sb.AppendLine("## Vitest stderr (tail)")'
  A '[void]$sb.AppendLine($fence)'
  A '$tailT = ($testRes.err -split "`r?`n") | Select-Object -Last 140'
  A '[void]$sb.AppendLine(($tailT -join "`r`n"))'
  A '[void]$sb.AppendLine($fence)'
  A '[void]$sb.AppendLine("")'
  A '[void]$sb.AppendLine("## Vite stderr (tail)")'
  A '[void]$sb.AppendLine($fence)'
  A '$tailB = ($buildRes.err -split "`r?`n") | Select-Object -Last 180'
  A '[void]$sb.AppendLine(($tailB -join "`r`n"))'
  A '[void]$sb.AppendLine($fence)'
  A '[void]$sb.AppendLine("")'
  A '[void]$sb.AppendLine("## Pointers")'
  A '[void]$sb.AppendLine("- Full log: " + $script:LogFile)'
  A 'Write-Utf8NoBom $md $sb.ToString()'
  A 'Log ("[PASS] Wrote diag report: {0}" -f $md)'
  A '$exitCode=0; if(-not $testRes.ok -or -not $buildRes.ok){ $exitCode=2 }'
  A 'Log ("[DONE] EXIT CODE: {0}" -f $exitCode)'
  A 'Write-Host ("[OK] Log: {0}" -f $script:LogFile)'
  A 'Write-Host ("[OK] Report: {0}" -f $md)'
  A 'exit $exitCode'

  Write-Utf8NoBom $diag (($L.ToArray()) -join "`r`n")
  LogLine "[PASS] Rewrote DIAG_REVIEW_FAIL_ONE_SHOT.ps1 to minimal known-good"
}

$errs2 = Parse-Syntax $diag
if ($errs2 -and $errs2.Count -gt 0) {
    
  LogLine ("[FATAL] Still parser errors: {0}" -f $errs2.Count)
  foreach($e in $errs2){ LogLine ("[FATAL] {0} (Line {1}, Col {2})" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) }
  exit 2
}

LogLine "[PASS] Parser check OK; running diag script"
& pwsh -ExecutionPolicy Bypass -File $diag -RepoRoot $repo -TimeoutSec $TimeoutSec
$rc = $LASTEXITCODE
LogLine ("[EXIT] DIAG_REVIEW_FAIL_ONE_SHOT.ps1 => {0}" -f $rc)
Write-Host ("[OK] Safe-run log: {0}" -f $log)
exit $rc
