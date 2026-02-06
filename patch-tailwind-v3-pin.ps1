# patch-tailwind-v3-pin.ps1
# Fix Tailwind build error: unknown utility `focus:ring-opacity-50`
# by pinning Tailwind toolchain to v3 (most compatible with ring-opacity utilities).

param(
  [ValidateSet("Detect","PinV3")]
  [string]$Mode = "PinV3"
)

$ErrorActionPreference = "Stop"
$RunId = (Get-Date).ToString("yyyyMMdd_HHmmss")
$LogPath = Join-Path $PWD "patch-tailwind.$RunId.log"

function L($m){
  $ts=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
  $line="$ts  $m"
  Write-Host $line
  Add-Content -Path $LogPath -Value $line
}

L "START Mode=$Mode"
L "PWD=$PWD"
if (!(Test-Path "package.json")) { throw "package.json not found at repo root." }

foreach($f in @("package.json","package-lock.json","tailwind.config.js","tailwind.config.cjs","tailwind.config.ts","postcss.config.js","postcss.config.cjs")){
  if(Test-Path $f){
    Copy-Item $f "$f.bak.$RunId" -Force
    L "BACKUP: $f -> $f.bak.$RunId"
  }
}

L "Node/NPM:"
try { L ("node: " + (& node -v)) } catch { L "node: (failed)" }
try { L ("npm: " + (& npm -v)) } catch { L "npm: (failed)" }

L "Current versions:"
try { (& npm ls tailwindcss postcss autoprefixer 2>&1) | ForEach-Object { L $_ } } catch { L $_.Exception.Message }

L "Searching for ring-opacity usage..."
try {
  (Select-String -Path .\src\**\*.{css,scss,js,jsx,ts,tsx} -Pattern "ring-opacity-" -ErrorAction SilentlyContinue) |
    ForEach-Object { L ("HIT: " + $_.Path + ":" + $_.LineNumber + "  " + $_.Line.Trim()) }
} catch {
  L "WARN: search failed: $($_.Exception.Message)"
}

if ($Mode -eq "Detect") {
  L "DONE Detect. LOG=$LogPath"
  exit 0
}

L "Pinning Tailwind toolchain to v3..."
# Install pinned versions; keeps existing semver ranges unless they were higher.
(& npm install -D tailwindcss@^3.4.17 postcss@^8.4.49 autoprefixer@^10.4.20 2>&1) | ForEach-Object { L $_ }

L "Recheck versions:"
(& npm ls tailwindcss postcss autoprefixer 2>&1) | ForEach-Object { L $_ }

L "Running build..."
(& npm run build 2>&1) | ForEach-Object { L $_ }

L "DONE PinV3. LOG=$LogPath"
