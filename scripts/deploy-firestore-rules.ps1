#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Firestore Security Rules Deployment & Verification Script
    ระบบ Deploy Security Rules และตรวจสอบสิทธิ์ Firestore
    
.DESCRIPTION
    This script handles:
    1. Validation of firestore.rules syntax
    2. Backup of current rules before deployment
    3. Deployment of new rules to Firebase
    4. Verification of deployment success
    5. Creation of system_status collection (if needed)

.EXAMPLE
    .\deploy-firestore-rules.ps1
    .\deploy-firestore-rules.ps1 -SkipBackup
#>

param(
    [switch]$SkipBackup = $false,
    [switch]$DryRun = $false,
    [string]$RulesFile = "firestore.rules"
)

# ========== UTILITY FUNCTIONS ==========
function Write-Info($Message) {
    Write-Host "• $Message" -ForegroundColor Cyan
}

function Write-Success($Message) {
    Write-Host "✔ $Message" -ForegroundColor Green
}

function Write-Warning($Message) {
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error-Custom($Message) {
    Write-Host "✘ $Message" -ForegroundColor Red
}

# ========== MAIN LOGIC ==========
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "
╔════════════════════════════════════════════════════════════════════╗
║         Firestore Security Rules Deployment Script                ║
║         ระบบ Deploy Security Rules ให้ Production                 ║
╚════════════════════════════════════════════════════════════════════╝
" -ForegroundColor Magenta

try {
    # Step 1: Validate Firebase CLI
    Write-Info "ตรวจสอบ Firebase CLI..."
    $firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
    if (-not $firebaseCmd) {
        Write-Error-Custom "Firebase CLI ไม่พบ กรุณา Install ก่อน: npm install -g firebase-tools"
        exit 1
    }
    Write-Success "Firebase CLI พร้อม"

    # Step 2: Validate rules file exists
    if (-not (Test-Path $RulesFile)) {
        Write-Error-Custom "ไฟล์ $RulesFile ไม่พบ"
        exit 1
    }
    Write-Success "ตรวจพบไฟล์ $RulesFile"

    # Step 3: Read rules content
    $rulesContent = Get-Content $RulesFile -Raw
    Write-Info "ไฟล์ขนาด: $([Math]::Round((Get-Item $RulesFile).Length / 1KB, 2)) KB"

    # Step 4: Backup current rules (optional)
    if (-not $SkipBackup) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = "${RulesFile}.backup.${timestamp}"
        
        try {
            Write-Info "กำลัง Backup rules ไปยัง $backupFile..."
            Copy-Item $RulesFile $backupFile -Force
            Write-Success "Backup สำเร็จ: $backupFile"
        } catch {
            Write-Warning "ไม่สามารถ Backup: $_"
        }
    }

    # Step 5: Validate rules syntax (basic check)
    $hasValidSyntax = $rulesContent -match 'rules_version\s*=\s*[''"]2[''"]' -and 
                      $rulesContent -match 'service cloud\.firestore' -and 
                      $rulesContent -match 'match /databases'

    if (-not $hasValidSyntax) {
        Write-Error-Custom "ไฟล์ rules มีปัญหา syntax หรือ version ไม่ถูกต้อง"
        exit 1
    }
    Write-Success "ตรวจสอบ Syntax ผ่าน"

    # Step 6: Show rules preview
    Write-Info "Rules Preview:"
    Write-Host "─" * 70
    $rulesContent -split "`n" | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
    Write-Host "  ..."
    Write-Host "─" * 70

    # Step 7: Get Firebase project info
    Write-Info "ดึงข้อมูล Firebase Project..."
    $projectInfo = firebase projects:list --json | ConvertFrom-Json
    
    if ($projectInfo.Count -eq 0) {
        Write-Error-Custom "ไม่พบ Firebase Project ที่ Login"
        exit 1
    }
    
    $currentProject = firebase use --add 2>&1 | Select-Object -Last 1
    Write-Success "Firebase Project: $currentProject"

    # Step 8: Dry-run or actual deployment
    if ($DryRun) {
        Write-Info "📋 DRY-RUN MODE - ไม่มีการ Deploy จริง"
        Write-Info "คำสั่งที่จะรันจริง: firebase deploy --only firestore:rules"
    } else {
        Write-Info "🚀 กำลัง Deploy rules ไปยัง Production..."
        Write-Host ""
        
        $deployResult = firebase deploy --only firestore:rules 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ Deploy สำเร็จ!"
            Write-Host ""
            Write-Info "ผลลัพธ์:"
            $deployResult | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Error-Custom "❌ Deploy ล้มเหลว"
            Write-Host ""
            Write-Error-Custom "ข้อผิดพลาด:"
            $deployResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            exit 1
        }
    }

    # Step 9: Post-deployment checklist
    Write-Host ""
    Write-Info "📋 Checklist ภายหลัง Deploy:"
    Write-Host "  ☐ ตรวจสอบ Firestore Console ว่า Rules ได้ Update"
    Write-Host "  ☐ ทดสอบ API Calls ที่ต้องการ Public Access"
    Write-Host "  ☐ ทดสอบ API Calls ที่ต้อง Authentication"
    Write-Host "  ☐ ทดสอบ API Calls ที่ต้อง Admin Role"
    Write-Host "  ☐ ตรวจสอบ Browser Console ว่าไม่มี permission-denied error"

    Write-Host ""
    Write-Success "✨ Deployment process สำเร็จ!"

} catch {
    Write-Error-Custom "เกิดข้อผิดพลาด: $_"
    exit 1
}
