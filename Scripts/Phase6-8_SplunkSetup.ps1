# ============================================================
# PHASE 6-8 - Splunk Server Setup Script
# Run this on the HOST machine as Administrator
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HOME SOC LAB - Splunk Server Setup"     -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- Step 1: Download Splunk Enterprise ---
Write-Host "`n[1/4] Checking Splunk installation..." -ForegroundColor Yellow

$splunkPath = "C:\Program Files\Splunk\bin\splunk.exe"

if (Test-Path $splunkPath) {
    Write-Host "  [OK] Splunk is already installed" -ForegroundColor Green
    $version = & $splunkPath version
    Write-Host "  Version: $version" -ForegroundColor White
} else {
    Write-Host "  [ACTION] Splunk Enterprise needs to be installed" -ForegroundColor Yellow
    Write-Host "  Download from: https://www.splunk.com/en_us/download.html" -ForegroundColor White
    Write-Host "  File: splunk-9.x.x-xxxxxxx-x64-release.msi" -ForegroundColor White
    Write-Host ""
    Write-Host "  Installation steps:" -ForegroundColor White
    Write-Host "    1. Run the MSI installer" -ForegroundColor White
    Write-Host "    2. Accept license → Next" -ForegroundColor White
    Write-Host "    3. Install to: C:\Program Files\Splunk" -ForegroundColor White
    Write-Host "    4. Check 'Customize install settings'" -ForegroundColor White
    Write-Host "    5. Select 'Local System' for logon" -ForegroundColor White
    Write-Host "    6. Click Install" -ForegroundColor White
    Write-Host ""
    Write-Host "  After installation, re-run this script." -ForegroundColor Yellow
    exit 0
}

# --- Step 2: Configure Splunk Receiving Port ---
Write-Host "`n[2/4] Configuring Splunk receiving port..." -ForegroundColor Yellow

# Enable listening on port 9997
& $splunkPath enable listen 9997 -auth admin:SOCadmin123! 2>&1 | Out-Null
Write-Host "  [OK] Receiving port 9997 enabled" -ForegroundColor Green

# --- Step 3: Create Custom Indexes ---
Write-Host "`n[3/4] Creating custom indexes..." -ForegroundColor Yellow

$indexes = @("windows_events", "sysmon_events", "powershell_logs", "network_logs")

foreach ($index in $indexes) {
    $result = & $splunkPath add index $index -auth admin:SOCadmin123! 2>&1
    if ($result -like "*already exists*") {
        Write-Host "  [OK] Index '$index' already exists" -ForegroundColor Gray
    } else {
        Write-Host "  [OK] Index '$index' created" -ForegroundColor Green
    }
}

# --- Step 4: Verify Splunk Web Access ---
Write-Host "`n[4/4] Verifying Splunk Web..." -ForegroundColor Yellow

$splunkWebUrl = "https://localhost:8000"
Write-Host "  Splunk Web URL: $splunkWebUrl" -ForegroundColor White
Write-Host "  Opening browser..." -ForegroundColor White

Start-Process $splunkWebUrl

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Splunk Server Setup Complete!"           -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Login to Splunk Web (admin / SOCadmin123!)" -ForegroundColor White
Write-Host "  2. Navigate to Settings → Forwarding and receiving" -ForegroundColor White
Write-Host "     → Receive data → Verify port 9997 is enabled" -ForegroundColor White
Write-Host "  3. Check for data from Windows VM:" -ForegroundColor White
Write-Host "     Search: index=_internal source=*metrics.log group=tcpin_connections" -ForegroundColor White
Write-Host "  4. Install Splunk Add-ons:" -ForegroundColor White
Write-Host "     - Apps → Find More Apps → Search 'Windows'" -ForegroundColor White
Write-Host "     - Install: Splunk Add-on for Microsoft Windows" -ForegroundColor White
Write-Host "     - Install: Splunk Add-on for Sysmon" -ForegroundColor White
Write-Host ""
Write-Host "  5. Run attack simulations (Phase 9)" -ForegroundColor White
Write-Host "  6. Create dashboards (Phase 10)" -ForegroundColor White
Write-Host "  7. Create alerts (Phase 11)" -ForegroundColor White
