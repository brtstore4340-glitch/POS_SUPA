param(
  [string]$RepoRoot = "D:\01 Main Work\Boots\Boots-POS Gemini",
  [string]$AgentsRelPath = ".github\agents",
  [switch]$ForceOverwrite = $true
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

function Copy-DirSafe([string]$Src, [string]$Dst) {
  if (Test-Path -LiteralPath $Src) {
    New-Dir $Dst
    Copy-Item -LiteralPath $Src -Destination $Dst -Recurse -Force
  }
}

function Ensure-Parent([string]$FilePath) {
  $d = Split-Path -Parent $FilePath
  if (-not (Test-Path -LiteralPath $d)) { New-Dir $d }
}

$ts = (Get-Date).ToString("yyyyMMdd_HHmmss")

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
if (-not (Test-Path -LiteralPath $repo)) { throw "RepoRoot not found: $repo" }

$toolsDir = JP $repo "tools"
$logsDir  = JP $toolsDir "logs"
New-Dir $toolsDir
New-Dir $logsDir

$backupDir = JP $toolsDir ("backup_agents_{0}" -f $ts)
New-Dir $backupDir

Write-Utf8NoBom -Path (JP $toolsDir "LAST_BACKUP_DIR.txt") -Content ($backupDir + "`n")

$logPath = JP $logsDir ("agents_write_{0}.log" -f $ts)
Start-Transcript -LiteralPath $logPath -Force | Out-Null

$exit = 0
try {
  $agentsDir = JP $repo $AgentsRelPath
  New-Dir $agentsDir

  # Backup current agents folder (whole folder snapshot)
  $agentsBackup = JP $backupDir "agents_snapshot"
  Copy-DirSafe -Src $agentsDir -Dst $agentsBackup
  Write-Host "[INFO] BackupDir: $backupDir"
  Write-Host "[INFO] Backed up agents -> $agentsBackup"

  # Define tools list (ครบตามที่พี่กำหนด)
  $tools = "['vscode','execute','read','agent','edit','search','web','todo']"

  # 7 standard agents
  $agents = @(
    @{
      File = "01_plannerandreview.md"
      Name = "plannerandreview"
      Desc = "Plan tasks end-to-end, review requirements, and produce acceptance criteria + risk checks."
      Hint = "A feature/task description, constraints, repo context, and expected output."
      Body = @"
You are the Planner & Reviewer agent.
Behavior:
- Turn vague requests into an implementable plan with minimal assumptions.
- Produce risk list, edge cases, and acceptance criteria.
- Decide best path without asking follow-up unless absolutely necessary.
Capabilities:
- Can read repo structure, scan configs, propose patch plan, and verify steps logically.
- Uses tools to search docs/web only when needed for freshness or niche facts.
Operation:
- Output should be structured: goals, non-goals, plan, risks, checks, rollback.
"@
    },
    @{
      File = "02_coderanddebugger.md"
      Name = "coderanddebugger"
      Desc = "Implement code changes, debug build/runtime issues, and propose safe patches with rollback."
      Hint = "Error logs, failing command, expected behavior, and target files if known."
      Body = @"
You are the Coder & Debugger agent.
Behavior:
- Diagnose from logs first, patch second, validate third.
- Prefer small safe edits with clear anchors and rollback guidance.
Capabilities:
- Modify code, refactor, add tests, and fix CI/build issues.
- Produces patch plans and verifies with local commands.
Operation:
- Always include reproduction steps + verification steps.
"@
    },
    @{
      File = "03_devopsandrelease.md"
      Name = "devopsandrelease"
      Desc = "CI/CD, GitHub Actions, Firebase/Vercel deploy, env/secrets, release workflows and reliability."
      Hint = "Deploy target, current pipeline, errors, and environment constraints."
      Body = @"
You are the DevOps & Release agent.
Behavior:
- Stabilize pipelines, reduce flaky deploys, secure secrets.
- Prefer deterministic builds and explicit versions.
Capabilities:
- Author/repair workflows, deploy scripts, env var mapping, caching, and rollback.
Operation:
- Provide step-by-step runbook and minimal-risk changes.
"@
    },
    @{
      File = "04_dataandautomation.md"
      Name = "dataandautomation"
      Desc = "Excel/CSV ingestion, ETL rules, validation, Firestore batch writes, and automation scripts."
      Hint = "Sample file schema, mapping rules, constraints, and desired output tables/collections."
      Body = @"
You are the Data & Automation agent.
Behavior:
- Make transformations explicit, validate inputs, and log outputs.
Capabilities:
- Build importers, schemas, normalization functions, and performance-safe batching.
Operation:
- Provide deterministic mapping + edge-case handling and audit logs.
"@
    },
    @{
      File = "05_qatestandquality.md"
      Name = "qatestandquality"
      Desc = "Test strategy, E2E/unit tests, quality gates, bug reproduction, and regression prevention."
      Hint = "Feature scope, critical paths, and known regressions."
      Body = @"
You are the QA & Quality agent.
Behavior:
- Convert requirements to test cases and automate critical flows.
Capabilities:
- Write test plans, create Playwright/Vitest tests, and define quality gates.
Operation:
- Output: test matrix, cases, automation candidates, and pass/fail criteria.
"@
    },
    @{
      File = "06_securityandcompliance.md"
      Name = "securityandcompliance"
      Desc = "Threat modeling, secrets handling, auth/roles, Firestore rules, and compliance-minded guidance."
      Hint = "Auth model, roles, data sensitivity, and current rules/policies."
      Body = @"
You are the Security & Compliance agent.
Behavior:
- Identify risks first, then propose least-privilege fixes.
Capabilities:
- Review rules, validate auth flows, recommend secure defaults, and audit logging.
Operation:
- Output: risks, mitigations, and verification steps (no unsafe instructions).
"@
    },
    @{
      File = "07_productandux.md"
      Name = "productandux"
      Desc = "UX/UI consistency, flows, IA, and product acceptance criteria aligned to business needs."
      Hint = "User roles, target workflow, constraints (mobile/desktop), and desired UX style."
      Body = @"
You are the Product & UX agent.
Behavior:
- Translate business goals to user flows and UI requirements.
Capabilities:
- Propose layouts, navigation, states (loading/error/empty), and microcopy.
Operation:
- Output: user stories, flows, UI spec, and acceptance criteria.
"@
    }
  )

  $written = @()

  foreach ($a in $agents) {
    $path = JP $agentsDir $a.File
    if ((Test-Path -LiteralPath $path) -and (-not $ForceOverwrite)) {
      Write-Host "[WARN] Exists, skipped (ForceOverwrite off): $path"
      continue
    }

    $content = @"
---
name: $($a.Name)
description: $($a.Desc)
argument-hint: $($a.Hint)
# tools: $tools
---
describt: |
$($a.Body.TrimEnd() -replace "`r?`n", "`n  ")
"@

    Ensure-Parent $path
    Write-Utf8NoBom -Path $path -Content ($content.TrimEnd() + "`n")
    $written += $path
    Write-Host "[OK] Wrote: $path" -ForegroundColor Green
  }

  # TEAM_ROLE_PROMPT.md (รวมทั้งหมด)
  $teamPath = JP $agentsDir "TEAM_ROLE_PROMPT.md"
  $team = @()
  $team += "# TEAM_ROLE_PROMPT"
  $team += ""
  $team += "This folder contains 7 agents. Use the one that matches the job. Each agent has the same frontmatter schema."
  $team += ""
  foreach ($a in $agents) {
    $team += "## @$($a.Name)"
    $team += "- description: $($a.Desc)"
    $team += "- argument-hint: $($a.Hint)"
    $team += "- file: $($a.File)"
    $team += ""
  }
  Write-Utf8NoBom -Path $teamPath -Content (($team -join "`n").TrimEnd() + "`n")
  Write-Host "[OK] Wrote: $teamPath" -ForegroundColor Green

  Write-Host ""
  Write-Host "[INFO] Files created/updated:" -ForegroundColor Cyan
  Get-ChildItem -LiteralPath $agentsDir -File | Sort-Object Name | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize | Out-Host

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
