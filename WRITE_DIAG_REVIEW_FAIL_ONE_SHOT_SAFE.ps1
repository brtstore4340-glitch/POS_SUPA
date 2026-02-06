# FILE: WRITE_DIAG_REVIEW_FAIL_ONE_SHOT_SAFE.ps1
# PURPOSE: Write DIAG_REVIEW_FAIL_ONE_SHOT.ps1 (parser-safe: no NowTs()), backup+logs, then run it.
# RUN:
#   pwsh -ExecutionPolicy Bypass -File .\WRITE_DIAG_REVIEW_FAIL_ONE_SHOT_SAFE.ps1 -RepoRoot "D:\01 Main Work\Boots\Boots-POS Gemini"

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
$writerLog = Join-Path $logsDir ("write_diag_review_fail_{0}.log" -f $ts)
Write-Utf8NoBom $writerLog ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo, (Get-Date).ToString("s"))
function WLog([string]$s){ Add-Content -LiteralPath $writerLog -Value ("[{0}] {1}" -f (Get-Date).ToString("s"), $s) -Encoding utf8 }

$backupDir = Join-Path $toolsDir ("backup_write_diag_review_fail_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")
WLog ("[INFO] BackupDir: {0}" -f $backupDir)

$target = Join-Path $repo "DIAG_REVIEW_FAIL_ONE_SHOT.ps1"
if (Test-Path -LiteralPath $target -PathType Leaf) {
  Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir "DIAG_REVIEW_FAIL_ONE_SHOT.ps1") -Force
  WLog "[INFO] Backed up existing DIAG_REVIEW_FAIL_ONE_SHOT.ps1"
}

$L = New-Object System.Collections.Generic.List[string]
function A([string]$s){ $script:L.Add($s) | Out-Null }

A '# FILE: DIAG_REVIEW_FAIL_ONE_SHOT.ps1'
A '# PURPOSE: Collect full evidence for vitest/vite failures with verbose stderr. No repo modifications.'
A 'param('
A '  [Parameter(Mandatory=$true)][string]$RepoRoot,'
A '  [int]$TimeoutSec = 1800'
A ')'
A ''
A 'Set-StrictMode -Version Latest'
A '$ErrorActionPreference = "Stop"'
A 'trap { try { Write-Host ("[FATAL] " + $_.Exception.Message) } catch {}; exit 1 }'
A ''
A 'function New-Dir([string]$Path){ if(-not (Test-Path -LiteralPath $Path)){ New-Item -ItemType Directory -Path $Path -Force | Out-Null } }'
A 'function Write-Utf8NoBom([string]$Path,[string]$Content){ $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path,$Content,$enc) }'
A 'function Assert-Dir([string]$Path,[string]$Name){ if(-not (Test-Path -LiteralPath $Path -PathType Container)){ throw ("Missing {0} directory: {1}" -f $Name,$Path) } }'
A ''
A '$repo=(Resolve-Path -LiteralPath $RepoRoot).Path'
A 'Assert-Dir $repo "RepoRoot"'
A '$toolsDir=Join-Path $repo "tools"'
A '$logsDir=Join-Path $toolsDir "logs"'
A '$reviewDir=Join-Path $toolsDir "review"'
A 'New-Dir $toolsDir; New-Dir $logsDir; New-Dir $reviewDir'
A ''
A '$ts = Get-Date -Format "yyyyMMdd_HHmmss"'
A '$logFile=Join-Path $logsDir ("diag_review_fail_{0}.log" -f $ts)'
A 'Write-Utf8NoBom $logFile ("[INFO] RepoRoot: {0}`r`n[INFO] Start: {1}`r`n" -f $repo,(Get-Date).ToString("s"))'
A 'function Log([string]$Line){ $t=(Get-Date).ToString("s"); Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f $t,$Line) -Encoding utf8 }'
A ''
A '$backupDir=Join-Path $toolsDir ("backup_diag_review_fail_{0}" -f $ts)'
A 'New-Dir $backupDir'
A 'Write-Utf8NoBom (Join-Path $toolsDir "LAST_BACKUP_DIR.txt") ($backupDir + "`r`n")'
A 'Log ("[INFO] BackupDir: {0}" -f $backupDir)'
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
A '# Evidence'
A '$pkg=Join-Path $repo "package.json"'
A 'if(-not (Test-Path -LiteralPath $pkg -PathType Leaf)){ Log "[FATAL] Missing package.json"; throw "Missing package.json" }'
A '$pkgRaw=Get-Content -LiteralPath $pkg -Raw'
A '$pkgObj=$null'
A 'try{ $pkgObj=$pkgRaw | ConvertFrom-Json }catch{ $pkgObj=$null }'
A 'Log "[INFO] package.json loaded"'
A 'if($pkgObj -and $pkgObj.scripts){ $names=$pkgObj.scripts.PSObject.Properties.Name; Log ("[INFO] scripts: " + ($names -join ", ")) } else { Log "[WARN] scripts missing/unreadable" }'
A ''
A '$binDir=Join-Path $repo "node_modules\.bin"'
A '$viteCmd=Join-Path $binDir "vite.cmd"'
A '$vitestCmd=Join-Path $binDir "vitest.cmd"'
A 'function BinInfo([string]$p){ if(Test-Path -LiteralPath $p -PathType Leaf){ $fi=Get-Item -LiteralPath $p; return ("FOUND ({0} bytes): {1}" -f $fi.Length,$p) } return ("MISSING: {0}" -f $p) }'
A 'Log ("[INFO] " + (BinInfo $vitestCmd))'
A 'Log ("[INFO] " + (BinInfo $viteCmd))'
A ''
A '# Run'
A '$testCmd="npm exec -- vitest run --watch=false --reporter=verbose"'
A '$testRes=Invoke-CmdLine "Vitest (CI run)" $testCmd $repo $TimeoutSec'
A '$buildCmd="set DEBUG=vite:*&& npm exec -- vite build --debug"'
A '$buildRes=Invoke-CmdLine "Vite build (debug)" $buildCmd $repo $TimeoutSec'
A ''
A '# Write md summary'
A '$fence=[string]::new([char]96,3)'
A '$mdPath=Join-Path $reviewDir ("DIAG_REVIEW_FAIL_{0}.md" -f $ts)'
A '$sb=New-Object System.Text.StringBuilder'
A '[void]$sb.AppendLine("# DIAG REVIEW FAIL " + $ts)'
A '[void]$sb.AppendLine("")'
A '[void]$sb.AppendLine("RepoRoot: " + $repo)'
A '[void]$sb.AppendLine("")'
A '[void]$sb.AppendLine("## Evidence")'
A '[void]$sb.AppendLine("- package.json: present")'
A '[void]$sb.AppendLine("- vitest.cmd: " + (BinInfo $vitestCmd))'
A '[void]$sb.AppendLine("- vite.cmd: " + (BinInfo $viteCmd))'
A '[void]$sb.AppendLine("")'
A '[void]$sb.AppendLine("## Results (summary)")'
A '[void]$sb.AppendLine(("- Vitest exit code: {0}" -f $testRes.code))'
A '[void]$sb.AppendLine(("- Vite exit code: {0}" -f $buildRes.code))'
A '[void]$sb.AppendLine("")'
A '[void]$sb.AppendLine("## Vitest stderr (tail)")'
A '[void]$sb.AppendLine($fence)'
A '$tailTest = ($testRes.err -split "`r?`n") | Select-Object -Last 140'
A '[void]$sb.AppendLine(($tailTest -join "`r`n"))'
A '[void]$sb.AppendLine($fence)'
A '[void]$sb.AppendLine("")'
A '[void]$sb.AppendLine("## Vite stderr (tail)")'
A '[void]$sb.AppendLine($fence)'
A '$tailBuild = ($buildRes.err -split "`r?`n") | Select-Object -Last 180'
A '[void]$sb.AppendLine(($tailBuild -join "`r`n"))'
A '[void]$sb.AppendLine($fence)'
A '[void]$sb.AppendLine("")'
A '[void]$sb.AppendLine("## Pointers")'
A '[void]$sb.AppendLine("- Full log: " + $logFile)'
A ''
A 'Write-Utf8NoBom $mdPath $sb.ToString()'
A 'Log ("[PASS] Wrote diag report: {0}" -f $mdPath)'
A '$exitCode=0'
A 'if(-not $testRes.ok){ $exitCode=2 }'
A 'if(-not $buildRes.ok){ $exitCode=2 }'
A 'Log ("[DONE] EXIT CODE: {0}" -f $exitCode)'
A 'Write-Host ("[OK] Log: {0}" -f $logFile)'
A 'Write-Host ("[OK] Report: {0}" -f $mdPath)'
A 'exit $exitCode'

Write-Utf8NoBom $target (($L.ToArray()) -join "`r`n")
WLog ("[PASS] Wrote: {0}" -f $target)

$errs = Parse-Syntax $target
if ($errs -and $errs.Count -gt 0) {
  WLog ("[FATAL] Parser errors in generated file: {0}" -f $errs.Count)
  foreach ($e in $errs) { WLog ("[FATAL] {0} (Line {1}, Col {2})" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) }
  exit 2
}
WLog "[PASS] Parser check OK"

& pwsh -ExecutionPolicy Bypass -File $target -RepoRoot $repo -TimeoutSec $TimeoutSec
$rc = $LASTEXITCODE
WLog ("[EXIT] DIAG_REVIEW_FAIL_ONE_SHOT.ps1 => {0}" -f $rc)

Write-Host ("[OK] Writer log: {0}" -f $writerLog)
exit $rc
