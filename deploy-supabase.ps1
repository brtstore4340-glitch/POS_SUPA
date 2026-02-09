# deploy-supabase.ps1
#
# USAGE
#   ./deploy-supabase.ps1
#
# Be sure to be logged in to Supabase before running.
#

# Load .env.local if it exists
$envPath = Join-Path $PSScriptRoot ".env.local"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and !$line.StartsWith("#")) {
            $parts = $line -split '=', 2
            if ($parts.Length -eq 2) {
                $key = $parts[0].Trim()
                $value = $parts[1].Trim()
                if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                [System.Environment]::SetEnvironmentVariable($key, $value, 'Process')
            }
        }
    }
}

function Info($m){Write-Host ('• '+$m) -ForegroundColor Cyan}
function Ok($m){Write-Host ('✔ '+$m) -ForegroundColor Green}
function Warn($m){Write-Host ('⚠ '+$m) -ForegroundColor Yellow}
function Err($m){Write-Host ('✖ '+$m) -ForegroundColor Red}

# Read project ref from supabase\config.toml (if present)
$projectRef = $null
$configPath = Join-Path $PSScriptRoot "supabase\\config.toml"
if (Test-Path $configPath) {
    foreach ($line in (Get-Content $configPath)) {
        if ($line -match '^\s*project_id\s*=\s*"([^"]+)"') {
            $projectRef = $Matches[1]
            break
        }
    }
}

# Am I logged in to Supabase?
npx supabase projects list | Out-Null
if ($LASTEXITCODE -ne 0) {
    Err "You are not logged in to Supabase. Please run 'npx supabase login' and try again."
    exit 1
}

Ok "You are logged in to Supabase."

# Ensure project is linked
$linkedConfig = Join-Path $PSScriptRoot ".supabase\\config.toml"
if (-not (Test-Path $linkedConfig)) {
    if ([string]::IsNullOrWhiteSpace($projectRef)) {
        Err "Supabase project is not linked and no project_id was found in supabase\\config.toml."
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($env:SUPABASE_DB_PASSWORD)) {
        Err ("Supabase project is not linked. Run 'npx supabase link --project-ref " + $projectRef + "' (you will be prompted for the DB password).")
        exit 1
    }

    Info ("Linking to Supabase project " + $projectRef + "...")
    npx supabase link --project-ref $projectRef --password $env:SUPABASE_DB_PASSWORD
    if ($LASTEXITCODE -ne 0) {
        Err "Supabase project linking failed."
        exit 1
    }
    Ok "Supabase project linked."
}

Info "Pushing database migrations..."
if ([string]::IsNullOrWhiteSpace($env:SUPABASE_DB_PASSWORD)) {
    npx supabase db push
} else {
    npx supabase db push --password $env:SUPABASE_DB_PASSWORD
}
if ($LASTEXITCODE -ne 0) {
    Err "Supabase database push failed."
    exit 1
}
Ok "Database migrations pushed."

$functionsPath = Join-Path $PSScriptRoot "supabase\\functions"
if (Test-Path $functionsPath) {
    $functionDirs = @(Get-ChildItem $functionsPath -Directory | Where-Object { $_.Name -ne "_shared" })
    if ($functionDirs.Count -eq 0) {
        Warn "No Edge functions found to deploy."
    } else {
        Info "Deploying Edge functions..."
        foreach ($fn in $functionDirs) {
            Info ("Deploying function: " + $fn.Name)
            npx supabase functions deploy $fn.Name
            if ($LASTEXITCODE -ne 0) {
                Err ("Function deployment failed: " + $fn.Name)
                exit 1
            }
        }
        Ok "Edge functions deployed."
    }
} else {
    Warn "supabase\\functions not found; skipping Edge function deploy."
}

Ok "Supabase deployment successful."
exit 0

Ok "Supabase deployment successful."
