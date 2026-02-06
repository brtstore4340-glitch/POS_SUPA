# patch-framer-motion.ps1
# Fix Vite build failing to resolve "framer-motion" by installing it as a runtime dependency.

param(
  [ValidateSet("Detect","Install")]
  [string]$Mode = "Install"
)

$ErrorActionPreference = "Stop"
$RunId = (Get-Date).ToString("yyyyMMdd_HHmmss")
$LogPath = Join-Path $PWD "patch-framer-motion.$RunId.log"

function L($m){
  $ts=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
  $line="$ts  $m"
  Write-Host $line
  Add-Content -Path $LogPath -Value $line
}

L "START Mode=$Mode"
L "PWD=$PWD"

if (!(Test-Path "package.json")) { throw "package.json not found at repo root." }

foreach($f in @("package.json","package-lock.json")){
  if(Test-Path $f){
    Copy-Item $f "$f.bak.$RunId" -Force
    L "BACKUP: $f -> $f.bak.$RunId"
  } else {
    L "WARN: Not found: $f"
  }
}

L "Node/NPM:"
try { L ("node: " + (& node -v)) } catch { L "node: (failed)" }
try { L ("npm: " + (& npm -v)) } catch { L "npm: (failed)" }

L "Checking current framer-motion tree..."
try {
  (& npm ls framer-motion 2>&1) | ForEach-Object { L $_ }
} catch {
  L "npm ls framer-motion exited non-zero (likely missing). Capturing message:"
  L $_.Exception.Message
}

if ($Mode -eq "Detect") {
  L "DONE Detect. LOG=$LogPath"
  exit 0
}

L "Installing framer-motion as dependency..."
(& npm install framer-motion 2>&1) | ForEach-Object { L $_ }

L "Rechecking framer-motion tree..."
(& npm ls framer-motion 2>&1) | ForEach-Object { L $_ }

L "Running production build..."
(& npm run build 2>&1) | ForEach-Object { L $_ }

L "DONE Install. LOG=$LogPath"
L "If build still fails, paste LOG content."
