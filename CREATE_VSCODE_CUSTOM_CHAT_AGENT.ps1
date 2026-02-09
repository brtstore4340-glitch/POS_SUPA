param(
  [Parameter(Mandatory=$false)][string]$ProjectName = "my-custom-ai-chat",
  [Parameter(Mandatory=$false)][string]$DisplayName = "My Custom AI",
  [Parameter(Mandatory=$false)][string]$ParticipantId = "myai",
  [Parameter(Mandatory=$false)][string]$OutDir = ".\tools\custom_chat_agent",
  [switch]$SkipInstallDeps
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

function Backup-Dir([string]$Path, [string]$BackupDir) {
  if (Test-Path -LiteralPath $Path) {
    $name = Split-Path -Leaf $Path
    $dest = JP $BackupDir $name
    Copy-Item -LiteralPath $Path -Destination $dest -Recurse -Force
    return $dest
  }
  return $null
}

function Assert-Command([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "Missing command: $Name" }
}

$ts = (Get-Date).ToString("yyyyMMdd_HHmmss")
$cwd = (Get-Location).Path

New-Dir (JP $cwd "tools")
New-Dir (JP $cwd "tools\logs")
$backupDir = JP $cwd ("tools\backup_create_custom_chat_agent_{0}" -f $ts)
New-Dir $backupDir
Write-Utf8NoBom -Path (JP $cwd "tools\LAST_BACKUP_DIR.txt") -Content ($backupDir + "`n")

$logPath = JP $cwd ("tools\logs\create_custom_chat_agent_{0}.log" -f $ts)
Start-Transcript -LiteralPath $logPath -Force | Out-Null

$exit = 0
try {
  Assert-Command "node"
  Assert-Command "npm"

  $outRoot = Resolve-Path -LiteralPath $OutDir -ErrorAction SilentlyContinue
  if (-not $outRoot) {
    New-Dir $OutDir
    $outRoot = Resolve-Path -LiteralPath $OutDir
  }

  $projRoot = JP $outRoot.Path $ProjectName

  $bk = Backup-Dir -Path $projRoot -BackupDir $backupDir
  if ($bk) { Write-Host "[INFO] Backed up existing project -> $bk" }

  if (Test-Path -LiteralPath $projRoot) {
    Remove-Item -LiteralPath $projRoot -Recurse -Force
  }
  New-Dir $projRoot
  New-Dir (JP $projRoot "src")

  # package.json (extension manifest)
  $packageJson = @"
{
  "name": "$ProjectName",
  "displayName": "$DisplayName",
  "description": "Custom Chat participant for VS Code Chat UI.",
  "version": "0.0.1",
  "publisher": "local",
  "engines": {
    "vscode": "^1.90.0"
  },
  "categories": ["Other"],
  "activationEvents": [
    "onChatParticipant:$ParticipantId"
  ],
  "main": "./dist/extension.js",
  "contributes": {
    "chatParticipants": [
      {
        "id": "$ParticipantId",
        "name": "$DisplayName",
        "description": "Talk to $DisplayName",
        "isSticky": true
      }
    ],
    "configuration": {
      "title": "$DisplayName",
      "properties": {
        "$ParticipantId.endpoint": {
          "type": "string",
          "default": "http://localhost:11434/v1/chat/completions",
          "description": "OpenAI-compatible endpoint for your custom AI."
        },
        "$ParticipantId.apiKey": {
          "type": "string",
          "default": "",
          "description": "API key (if required). Prefer SecretStorage in production."
        },
        "$ParticipantId.model": {
          "type": "string",
          "default": "gpt-4o-mini",
          "description": "Model name to send to your endpoint."
        }
      }
    }
  },
  "scripts": {
    "build": "tsc -p .",
    "package": "vsce package"
  },
  "devDependencies": {
    "@types/vscode": "^1.90.0",
    "typescript": "^5.5.0",
    "vsce": "^3.2.1"
  }
}
"@
  Write-Utf8NoBom -Path (JP $projRoot "package.json") -Content ($packageJson + "`n")

  # tsconfig.json
  $tsconfig = @"
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "sourceMap": true
  },
  "include": ["src"]
}
"@
  Write-Utf8NoBom -Path (JP $projRoot "tsconfig.json") -Content ($tsconfig + "`n")

  # src/extension.ts
  $extTs = @"
import * as vscode from "vscode";

type ChatReq = {
  model: string;
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>;
  stream?: boolean;
};

export function activate(context: vscode.ExtensionContext) {
  const participantId = "$ParticipantId";
  const handler: vscode.ChatRequestHandler = async (request, ctx, stream, token) => {
    const cfg = vscode.workspace.getConfiguration();
    const endpoint = cfg.get<string>(\`\${participantId}.endpoint\`) || "";
    const apiKey = cfg.get<string>(\`\${participantId}.apiKey\`) || "";
    const model = cfg.get<string>(\`\${participantId}.model\`) || "gpt-4o-mini";

    if (!endpoint) {
      stream.markdown("**Missing endpoint**. Set `${participantId}.endpoint` in Settings.");
      return;
    }

    const userText = request.prompt || "";
    const payload: ChatReq = {
      model,
      messages: [
        { role: "system", content: "You are a helpful assistant." },
        { role: "user", content: userText }
      ],
      stream: false
    };

    try {
      const headers: Record<string, string> = { "Content-Type": "application/json" };
      if (apiKey) headers["Authorization"] = \`Bearer \${apiKey}\`;

      const res = await fetch(endpoint, {
        method: "POST",
        headers,
        body: JSON.stringify(payload),
        signal: token.isCancellationRequested ? undefined : undefined
      });

      if (!res.ok) {
        const t = await res.text();
        stream.markdown(\`**HTTP \${res.status}**\\n\\n\${t}\`);
        return;
      }

      const json: any = await res.json();
      const answer =
        json?.choices?.[0]?.message?.content ??
        json?.choices?.[0]?.text ??
        "(no content)";
      stream.markdown(answer);
    } catch (e: any) {
      stream.markdown(\`**Error**: \${e?.message || String(e)}\`);
    }
  };

  const participant = vscode.chat.createChatParticipant(participantId, handler);
  participant.iconPath = new vscode.ThemeIcon("sparkle");
  context.subscriptions.push(participant);
}

export function deactivate() {}
"@
  Write-Utf8NoBom -Path (JP $projRoot "src\extension.ts") -Content ($extTs + "`n")

  # README
  $readme = @"
# $DisplayName (VS Code Chat Participant)

## Install
1) Open folder in VS Code.
2) Run in terminal:
   - npm i
   - npm run build
   - npm run package

## Use
Open Chat, then type: @$ParticipantId your question

## Settings
- $ParticipantId.endpoint
- $ParticipantId.apiKey
- $ParticipantId.model
"@
  Write-Utf8NoBom -Path (JP $projRoot "README.md") -Content ($readme + "`n")

  Write-Host "[INFO] Project created: $projRoot"

  if (-not $SkipInstallDeps) {
    Write-Host "[INFO] npm i"
    $p1 = Start-Process -FilePath "npm" -ArgumentList "i" -WorkingDirectory $projRoot -Wait -PassThru -NoNewWindow
    Write-Host ("[INFO] ExitCode(npm i) = {0}" -f $p1.ExitCode)
    if ($p1.ExitCode -ne 0) { throw "npm i failed" }

    Write-Host "[INFO] npm run build"
    $p2 = Start-Process -FilePath "npm" -ArgumentList "run build" -WorkingDirectory $projRoot -Wait -PassThru -NoNewWindow
    Write-Host ("[INFO] ExitCode(build) = {0}" -f $p2.ExitCode)
    if ($p2.ExitCode -ne 0) { throw "build failed" }

    Write-Host "[INFO] npm run package (vsix)"
    $p3 = Start-Process -FilePath "npm" -ArgumentList "run package" -WorkingDirectory $projRoot -Wait -PassThru -NoNewWindow
    Write-Host ("[INFO] ExitCode(package) = {0}" -f $p3.ExitCode)
    if ($p3.ExitCode -ne 0) { throw "vsix package failed" }

    $vsix = Get-ChildItem -LiteralPath $projRoot -Filter "*.vsix" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
    if ($vsix) {
      Write-Host ("[OK] VSIX created: {0}" -f $vsix.FullName) -ForegroundColor Green
    } else {
      Write-Host "[WARN] No .vsix found (package may be skipped by environment)."
    }
  } else {
    Write-Host "[INFO] Skip deps/build/package as requested."
  }

  Write-Host "[DONE] Open folder in VS Code, install VSIX, then use @participant in Chat." -ForegroundColor Cyan
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
