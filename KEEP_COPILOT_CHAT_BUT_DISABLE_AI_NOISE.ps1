param(
  [switch]$AlsoApplyToInsiders
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
  try { Write-Host "[FATAL] $($_.Exception.Message)" -ForegroundColor Red } catch {}
  exit 1
}

function To-Str([object]$v) {
  if ($null -eq $v) { return "" }
  if ($v -is [string]) { return $v }
  if ($v -is [System.Array]) { return (($v | ForEach-Object { $_.ToString() }) -join "") }
  return $v.ToString()
}

function JP([object]$Path, [object]$Child) {
  $p = To-Str $Path
  $c = To-Str $Child
  if ([string]::IsNullOrWhiteSpace($p)) { throw "Join-Path: Path is empty. Child='$c'" }
  if ([string]::IsNullOrWhiteSpace($c)) { return $p }
  return (Join-Path -Path $p -ChildPath $c)
}

function New-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $enc = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Backup-File([string]$Path, [string]$BackupDir) {
  if (Test-Path -LiteralPath $Path) {
    $name = Split-Path -Leaf $Path
    $dest = JP $BackupDir $name
    Copy-Item -LiteralPath $Path -Destination $dest -Force
    return $dest
  }
  return $null
}

function Read-JsonOrEmpty([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return @{} }
  $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
  if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
  try { return ($raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop) }
  catch { throw "Invalid JSON in: $Path" }
}

function Write-Json([string]$Path, [hashtable]$Obj) {
  $json = ($Obj | ConvertTo-Json -Depth 80)
  Write-Utf8NoBom -Path $Path -Content ($json + "`n")
}

$ts = (Get-Date).ToString("yyyyMMdd_HHmmss")
$cwd = (Get-Location).Path

New-Dir (JP $cwd "tools")
New-Dir (JP $cwd "tools\logs")
$backupDir = JP $cwd ("tools\backup_keep_copilot_chat_disable_noise_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom -Path (JP $cwd "tools\LAST_BACKUP_DIR.txt") -Content ($backupDir + "`n")

$logPath = JP $cwd ("tools\logs\keep_copilot_chat_disable_noise_{0}.log" -f $ts)
Start-Transcript -LiteralPath $logPath -Force | Out-Null

$exit = 0
try {
  $appdata = To-Str $env:APPDATA
  if ([string]::IsNullOrWhiteSpace($appdata)) { throw "APPDATA is empty." }
  if (-not (Test-Path -LiteralPath $appdata)) { throw "APPDATA path not found: $appdata" }

  $targets = @(
    (JP $appdata "Code\User\settings.json")
  )
  if ($AlsoApplyToInsiders) {
    $targets += (JP $appdata "Code - Insiders\User\settings.json")
  }

  foreach ($settingsPath in $targets) {
    $settingsDir = Split-Path -Parent $settingsPath
    if (-not (Test-Path -LiteralPath $settingsDir)) {
      Write-Host "[WARN] Skip (not found): $settingsDir"
      continue
    }

    Write-Host "[INFO] Target settings: $settingsPath"
    $bk = Backup-File -Path $settingsPath -BackupDir $backupDir
    if ($bk) { Write-Host "[INFO] Backed up -> $bk" }

    $obj = Read-JsonOrEmpty -Path $settingsPath

    # --- KEEP Copilot Chat, but reduce “AI noise” ---
    # 1) Disable Copilot auto completions (still keep chat)
    $obj["github.copilot.editor.enableAutoCompletions"] = $false

    # 2) Disable inline ghost text suggestions (global)
    $obj["editor.inlineSuggest.enabled"] = $false

    # 3) Disable agent mode (reduces autonomous / agent picker)
    $obj["chat.agent.enabled"] = $false

    # 4) Optional: reduce chat participant detection noise
    $obj["chat.detectParticipant.enabled"] = $false

    # 5) (Optional UI annoyance) hide empty editor hint
    if (-not $obj.ContainsKey("workbench.editor.empty.hint")) {
      $obj["workbench.editor.empty.hint"] = "hidden"
    }

    Write-Json -Path $settingsPath -Obj $obj
    Write-Host "[OK] Updated settings (keep Copilot Chat, disable suggestions/agent)" -ForegroundColor Green
  }

  Write-Host "[DONE] Close ALL VS Code windows, then reopen." -ForegroundColor Cyan
  Write-Host "[NOTE] Copilot Chat still works, but autocomplete/ghost text + agent mode are disabled." -ForegroundColor Cyan
  $exit = 0
} catch {
  Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
  $exit = 1
} finally {
  try { Stop-Transcript | Out-Null } catch {}
  Write-Host ("[SUMMARY] Log: {0}" -f $logPath)
  Write-Host ("[SUMMARY] ExitCode = {0}" -f $exit)
  exit $exit
}
