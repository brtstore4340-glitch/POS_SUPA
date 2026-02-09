<#
.SYNOPSIS
  CleanupScript.ps1 - Cleanup script for Boots-POS Gemini repo per specifications

.DESCRIPTION
  Dry-run mode by default, deletes actual only with -Apply.
  Backs up target deletions, logs output, summarizes.

.PARAMETER Apply
  If specified, performs actual deletions.

.PARAMETER DeleteAllPS1
  If specified, deletes all PS1 files repo-wide (dangerous).

.EXAMPLE
  .\CleanupScript.ps1
  # Dry-run default, no actual deletion.

  .\CleanupScript.ps1 -Apply -DeleteAllPS1
  # Perform actual deletions including all PS1 files.
#>

[CmdletBinding()]
param (
    [switch]$Apply,
    [switch]$DeleteAllPS1
)

function Write-Log {
    param (
        [string]$Message,
        [switch]$Error,
        [switch]$Warning
    )
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timeStamp] $Message"
    Add-Content -Path $Global:LogFile -Value $line
    if ($Error) {
        Write-Error $Message
    } elseif ($Warning) {
        Write-Warning $Message
    } else {
        Write-Output $Message
    }
}

function Remove-ItemSafe {
    param (
        [Parameter(Mandatory=$true)] $Item,
        [switch]$IsDirectory
    )
    try {
        # Remove readonly and hidden before removal
        $attrs = $Item.Attributes
        if ($attrs -band [IO.FileAttributes]::ReadOnly -or $attrs -band [IO.FileAttributes]::Hidden) {
            $Item.Attributes = $attrs -band -not ([IO.FileAttributes]::ReadOnly + [IO.FileAttributes]::Hidden)
        }
        Remove-Item -LiteralPath $Item.FullName -Recurse:$IsDirectory -Force -ErrorAction Stop -WhatIf:$WhatIfMode
        return $true
    } catch {
        Write-Log "Failed to delete '$($Item.FullName)': $_" -Error
        $Global:FailureCount++
        $Global:FailureDetails += "Failed to delete '$($Item.FullName)': $_`n"
        return $false
    }
}

# Setup environment
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path "$ScriptDir\.."
$ToolsDir = Join-Path $RepoRoot "tools"
$LogsDir = Join-Path $ToolsDir "logs"
if (-not (Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir | Out-Null
}

# Log file setup
$timeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:LogFile = Join-Path $LogsDir "cleanup_$timeStamp.log"
$Global:FailureCount = 0
$Global:FailureDetails = ""

# Determine WhatIf mode
$WhatIfMode = -not $Apply

Write-Log "Starting cleanup script. Apply mode: $Apply. DeleteAllPS1: $DeleteAllPS1. Dry-run mode: $WhatIfMode"

# Prepare backup dir if apply
if ($Apply) {
    $BackupDirName = "backup_cleanup_$timeStamp"
    $BackupDir = Join-Path $ToolsDir $BackupDirName
    New-Item -ItemType Directory -Path $BackupDir -ErrorAction Stop | Out-Null
    Write-Log "Backup directory created at '$BackupDir'"
} else {
    $BackupDir = $null
}

# Function to get size formatted
function Get-HumanSize {
    param([long]$bytes)
    if ($bytes -ge 1GB) {
        "{0:N2} GB" -f ($bytes /1GB)
    } elseif ($bytes -ge 1MB) {
        "{0:N2} MB" -f ($bytes /1MB)
    } elseif ($bytes -ge 1KB) {
        "{0:N2} KB" -f ($bytes /1KB)
    } else {
        "$bytes bytes"
    }
}

# Collect targets (files and directories)
$PlannedDeletions = @()

# 1. Directories named tools/backup_* under tools only
$backupDirs = Get-ChildItem -Path $ToolsDir -Directory -Filter "backup_*" -ErrorAction SilentlyContinue
foreach ($dir in $backupDirs) {
    # Confirm name actually starts with backup_ (some could be backup123)
    if ($dir.Name -like "backup_*") {
        $PlannedDeletions += [PSCustomObject]@{
            Item = $dir
            Type = "dir"
            Size = 0  # calculate later recursively if needed, skipping size for directories now
        }
    }
}

# 2. Files with ".bak_" anywhere in repo
$allFiles = Get-ChildItem -Path $RepoRoot -Recurse -File -ErrorAction SilentlyContinue
foreach ($file in $allFiles) {
    if ($file.Name -like "*.bak_*") {
        $PlannedDeletions += [PSCustomObject]@{
            Item = $file
            Type = "file"
            Size = $file.Length
        }
    }
}

# 3. .ps1 files deletion scope
# Default: only delete tools*.ps1 files (in tools dir only)
if ($DeleteAllPS1) {
    # all *.ps1 files in repo
    $ps1files = Get-ChildItem -Path $RepoRoot -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue
} else {
    # only tools*.ps1 in tools dir (non-recursive)
    $ps1files = Get-ChildItem -Path $ToolsDir -File -Include *.ps1 -ErrorAction SilentlyContinue
}
foreach ($ps1file in $ps1files) {
    $PlannedDeletions += [PSCustomObject]@{
        Item = $ps1file
        Type = "file"
        Size = $ps1file.Length
    }
}

# Sort deletions: files first, then directories
$PlannedDeletions = $PlannedDeletions | Sort-Object Type

# Generate manifest targets text file if apply
if ($Apply) {
    $ManifestPath = Join-Path $BackupDir "manifest_targets.txt"
    $ManifestLines = @()
    foreach ($del in $PlannedDeletions) {
        $size = $del.Type -eq "file" ? $del.Size : 0
        $ManifestLines += "{0}`t{1}`t{2}" -f $del.Type, $size, $del.Item.FullName
    }
    $ManifestLines | Out-File -FilePath $ManifestPath -Encoding UTF8
    Write-Log "Manifest of targets written to '$ManifestPath'"
}

# Backup files before deletion if apply - copy files (not directories backup)
if ($Apply) {
    foreach ($del in $PlannedDeletions) {
        if ($del.Type -eq "file") {
            $source = $del.Item.FullName
            $dest = Join-Path $BackupDir ([IO.Path]::GetFileName($source))
            try {
                Copy-Item -LiteralPath $source -Destination $dest -Force -ErrorAction Stop
            } catch {
                Write-Log "Failed to backup '$source': $_" -Error
                $Global:FailureCount++
                $Global:FailureDetails += "Failed to backup '$source': $_`n"
            }
        }
    }
}

# Plan counts and sizes
$PlannedFileCount = ($PlannedDeletions | Where-Object { $_.Type -eq "file" }).Count
$PlannedDirCount = ($PlannedDeletions | Where-Object { $_.Type -eq "dir" }).Count
$PlannedTotalBytes = ($PlannedDeletions | Where-Object { $_.Type -eq "file" } | Measure-Object -Property Size -Sum).Sum
if (-not $PlannedTotalBytes) { $PlannedTotalBytes = 0 }

$DeletedFileCount = 0
$DeletedDirCount = 0
$DeletedTotalBytes = 0

# Deletion phase
foreach ($del in $PlannedDeletions) {
    if ($del.Type -eq "file") {
        if (Remove-ItemSafe -Item $del.Item) {
            $DeletedFileCount++
            $DeletedTotalBytes += $del.Size
            Write-Log "Deleted file: $($del.Item.FullName)"
        } else {
            Write-Log "Failed deleting file: $($del.Item.FullName)" -Error
        }
    }
}

foreach ($del in $PlannedDeletions) {
    if ($del.Type -eq "dir") {
        if (Remove-ItemSafe -Item $del.Item -IsDirectory) {
            $DeletedDirCount++
            Write-Log "Deleted directory: $($del.Item.FullName)"
        } else {
            Write-Log "Failed deleting directory: $($del.Item.FullName)" -Error
        }
    }
}

# Update LAST_BACKUP_DIR.txt if apply
if ($Apply) {
    $LastBackupFile = Join-Path $ToolsDir "LAST_BACKUP_DIR.txt"
    try {
        Set-Content -Path $LastBackupFile -Value $BackupDir -Encoding UTF8 -ErrorAction Stop
        Write-Log "Updated LAST_BACKUP_DIR.txt with backup path."
    } catch {
        Write-Log "Failed to update LAST_BACKUP_DIR.txt: $_" -Error
        $Global:FailureCount++
        $Global:FailureDetails += "Failed to update LAST_BACKUP_DIR.txt: $_`n"
    }
}

# Summary and exit code
Write-Log "Cleanup Summary:"
Write-Log " Planned deletions: Files=$PlannedFileCount, Directories=$PlannedDirCount, TotalBytes=$(Get-HumanSize $PlannedTotalBytes)"
Write-Log " Actual deletions: Files=$DeletedFileCount, Directories=$DeletedDirCount, TotalBytes=$(Get-HumanSize $DeletedTotalBytes)"
Write-Log " Failures: $($Global:FailureCount)"
if ($Global:FailureCount -gt 0) {
    Write-Log "Failure details:`n$($Global:FailureDetails)" -Error
}

if (($DeletedFileCount + $DeletedDirCount) -eq 0 -and $PlannedFileCount + $PlannedDirCount -gt 0) {
    # Nothing deleted when deletions planned => fatal
    Write-Log "Fatal error: Planned deletions found but none deleted." -Error
    exit 1
} elseif ($Global:FailureCount -gt 0) {
    # Some deletions failed => partial failures
    exit 2
} else {
    # Success
    exit 0
}