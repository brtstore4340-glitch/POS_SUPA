param(
  [string]$Url = "https://asia-southeast1-boots-4340-project.cloudfunctions.net/bootstrapAdmin"
)

$ErrorActionPreference = "Stop"
$RunId = (Get-Date).ToString("yyyyMMdd_HHmmss")
$OutDir = Join-Path $PWD "diag-bootstrapAdmin.$RunId"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$LogPath = Join-Path $OutDir "diag.log"

function L($m){
  $ts=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
  $line="$ts  $m"
  Write-Host $line
  Add-Content -Path $LogPath -Value $line
}

L "START"
L "URL=$Url"

# GET
try {
  $r = Invoke-WebRequest -Uri $Url -Method GET -UseBasicParsing -ErrorAction Stop
  L "GET status=$($r.StatusCode)"
  Set-Content -Path (Join-Path $OutDir "get-body.txt") -Value $r.Content -Encoding UTF8
} catch {
  L "GET failed: $($_.Exception.Message)"
  if ($_.Exception.Response) {
    $resp = $_.Exception.Response
    L "GET status=$([int]$resp.StatusCode)"
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $txt = $sr.ReadToEnd()
    Set-Content -Path (Join-Path $OutDir "get-body-error.txt") -Value $txt -Encoding UTF8
    L "GET error body saved"
  }
}

# POST JSON
try {
  $payload = @{ ping="ping"; ts=$RunId } | ConvertTo-Json
  $r2 = Invoke-WebRequest -Uri $Url -Method POST -ContentType "application/json" -Body $payload -UseBasicParsing -ErrorAction Stop
  L "POST status=$($r2.StatusCode)"
  Set-Content -Path (Join-Path $OutDir "post-body.txt") -Value $r2.Content -Encoding UTF8
} catch {
  L "POST failed: $($_.Exception.Message)"
  if ($_.Exception.Response) {
    $resp = $_.Exception.Response
    L "POST status=$([int]$resp.StatusCode)"
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $txt = $sr.ReadToEnd()
    Set-Content -Path (Join-Path $OutDir "post-body-error.txt") -Value $txt -Encoding UTF8
    L "POST error body saved"
  }
}

L "DONE out=$OutDir"
