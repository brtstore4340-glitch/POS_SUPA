param(
  [string]$Url = "https://asia-southeast1-boots-4340-project.cloudfunctions.net/bootstrapAdmin"
)

$ErrorActionPreference="Stop"

function Read-ErrorBody($ex){
  if ($ex.Exception.Response) {
    $resp = $ex.Exception.Response
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
    return $sr.ReadToEnd()
  }
  return $null
}

Write-Host "URL=$Url"

Write-Host "`n=== GET ==="
try {
  $r = Invoke-WebRequest -Uri $Url -Method GET -UseBasicParsing -ErrorAction Stop
  Write-Host "status=$($r.StatusCode)"
  Write-Host $r.Content
} catch {
  $body = Read-ErrorBody $_
  Write-Host "GET failed: $($_.Exception.Message)"
  if ($body) { Write-Host "Body:`n$body" }
}

Write-Host "`n=== POST JSON ==="
try {
  $payload = @{ ping="ping" } | ConvertTo-Json
  $r2 = Invoke-WebRequest -Uri $Url -Method POST -ContentType "application/json" -Body $payload -UseBasicParsing -ErrorAction Stop
  Write-Host "status=$($r2.StatusCode)"
  Write-Host $r2.Content
} catch {
  $body = Read-ErrorBody $_
  Write-Host "POST failed: $($_.Exception.Message)"
  if ($body) { Write-Host "Body:`n$body" }
}
