# patch-firebase-import.ps1
# Fix Vite import error for ../../firebase/config.js from src/modules/auth/pages/Login.jsx
# by creating a compatibility shim at src/modules/firebase/config.js when appropriate.

$ErrorActionPreference = "Stop"
$RunId = (Get-Date).ToString("yyyyMMdd_HHmmss")
$LogPath = Join-Path $PWD "patch-firebase-import.$RunId.log"

function L($m){
  $ts=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
  $line="$ts  $m"
  Write-Host $line
  Add-Content -Path $LogPath -Value $line
}

L "START"
L "PWD=$PWD"

$loginPath = ".\src\modules\auth\pages\Login.jsx"
if (!(Test-Path $loginPath)) { throw "Missing expected file: $loginPath" }

# Backups
foreach($f in @($loginPath, ".\package.json", ".\package-lock.json")){
  if (Test-Path $f) {
    Copy-Item $f "$f.bak.$RunId" -Force
    L "BACKUP: $f -> $f.bak.$RunId"
  }
}

# Expected by current import resolution:
$expectedShim = ".\src\modules\firebase\config.js"
# Common actual location:
$rootConfig = ".\src\firebase\config.js"

L "Checking paths:"
L "Expected by import: $expectedShim"
L "Common root config: $rootConfig"

$login = Get-Content $loginPath -Raw
L "Login.jsx first lines:"
($login -split "`n" | Select-Object -First 5) | ForEach-Object { L $_.TrimEnd() }

if (Test-Path $expectedShim) {
  L "OK: $expectedShim already exists. Build error likely due to different path/case/extension. No changes made."
  L "DONE. LOG=$LogPath"
  exit 0
}

if (!(Test-Path $rootConfig)) {
  L "BLOCKER: Neither $expectedShim nor $rootConfig exists."
  L "Find candidates:"
  Get-ChildItem -Recurse -File -Path .\src -Filter "config.js" | ForEach-Object { L ("CANDIDATE: " + $_.FullName) }
  L "DONE (no changes). LOG=$LogPath"
  exit 2
}

# Create shim folder + file
$shimDir = Split-Path $expectedShim -Parent
if (!(Test-Path $shimDir)) {
  New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
  L "Created directory: $shimDir"
}

# From src/modules/firebase/config.js -> src/firebase/config.js is ../../firebase/config.js
$shimContent = @'
export * from "../../firebase/config.js";
'@

Set-Content -Path $expectedShim -Value $shimContent -Encoding UTF8
L "Created shim: $expectedShim"
L "Shim content: export * from ""../../firebase/config.js"";"

L "Running build..."
(& npm run build 2>&1) | ForEach-Object { L $_ }

L "DONE. LOG=$LogPath"
