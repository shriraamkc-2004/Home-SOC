# ============================================================
# PHASE 1 - System Preparation Script
# Run this as ADMINISTRATOR on your Host Windows 11 machine
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HOME SOC LAB - Phase 1: System Check"   -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- Step 1: Hardware Check ---
Write-Host "`n[1/5] Checking Hardware..." -ForegroundColor Yellow

$cpu = Get-CimInstance Win32_Processor
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$disk = Get-PSDrive C
$freeGB = [math]::Round($disk.Free / 1GB, 1)

Write-Host "  CPU: $($cpu.Name)" -ForegroundColor White
Write-Host "  Cores: $($cpu.NumberOfCores) physical / $($cpu.NumberOfLogicalProcessors) logical" -ForegroundColor White
Write-Host "  RAM: ${ramGB} GB" -ForegroundColor White
Write-Host "  Disk Free: ${freeGB} GB" -ForegroundColor White

# Check requirements
$errors = @()
if ($cpu.NumberOfCores -lt 4) { $errors += "  [FAIL] Need at least 4 CPU cores (you have $($cpu.NumberOfCores))" }
if ($ramGB -lt 16) { $errors += "  [WARN] Recommend 16+ GB RAM (you have ${ramGB} GB)" }
if ($freeGB -lt 100) { $errors += "  [FAIL] Need at least 100 GB free (you have ${freeGB} GB)" }

if ($errors.Count -gt 0) {
    Write-Host "`n  Hardware Issues Found:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
} else {
    Write-Host "  [OK] Hardware meets requirements" -ForegroundColor Green
}

# --- Step 2: Check Virtualization ---
Write-Host "`n[2/5] Checking Virtualization..." -ForegroundColor Yellow

$vz = (Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled
if ($vz) {
    Write-Host "  [OK] Virtualization is ENABLED in BIOS" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Virtualization is NOT enabled" -ForegroundColor Red
    Write-Host "  ACTION REQUIRED:" -ForegroundColor Red
    Write-Host "    1. Restart your laptop" -ForegroundColor White
    Write-Host "    2. Enter BIOS (F2/F10/DEL during boot)" -ForegroundColor White
    Write-Host "    3. Enable Intel VT-x or AMD-V / SVM" -ForegroundColor White
    Write-Host "    4. Save and reboot, then re-run this script" -ForegroundColor White
    Write-Host "`n  Cannot continue without virtualization. Exiting." -ForegroundColor Red
    exit 1
}

# --- Step 3: Check if Hyper-V needs disabling (for VirtualBox) ---
Write-Host "`n[3/5] Checking Hyper-V status..." -ForegroundColor Yellow

$hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
if ($hyperv -and $hyperv.State -eq "Enabled") {
    Write-Host "  [WARN] Hyper-V is ENABLED - this can conflict with VirtualBox" -ForegroundColor Yellow
    Write-Host "  Do you want to disable Hyper-V? (Recommended for VirtualBox)" -ForegroundColor Yellow
    $choice = Read-Host "  Enter Y to disable, N to keep (Y/N)"
    if ($choice -eq "Y" -or $choice -eq "y") {
        Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
        bcdedit /set hypervisorlaunchtype off
        Write-Host "  [OK] Hyper-V disabled. REBOOT REQUIRED before using VirtualBox." -ForegroundColor Green
    }
} else {
    Write-Host "  [OK] Hyper-V is not enabled (good for VirtualBox)" -ForegroundColor Green
}

# --- Step 4: Check if VirtualBox is already installed ---
Write-Host "`n[4/5] Checking VirtualBox installation..." -ForegroundColor Yellow

$vboxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if (Test-Path $vboxPath) {
    $vboxVersion = & $vboxPath --version
    Write-Host "  [OK] VirtualBox is installed: $vboxVersion" -ForegroundColor Green
} else {
    Write-Host "  [ACTION] VirtualBox is NOT installed" -ForegroundColor Yellow
    Write-Host "  Downloading VirtualBox installer..." -ForegroundColor Yellow

    $vboxUrl = "https://download.virtualbox.org/virtualbox/7.1.6/VirtualBox-7.1.6-163684-Win.exe"
    $vboxInstaller = "$env:USERPROFILE\Downloads\VirtualBox-installer.exe"

    try {
        Invoke-WebRequest -Uri $vboxUrl -OutFile $vboxInstaller -UseBasicParsing
        Write-Host "  [OK] Downloaded to: $vboxInstaller" -ForegroundColor Green
        Write-Host "  [ACTION] Please run the installer manually:" -ForegroundColor Yellow
        Write-Host "    Double-click: $vboxInstaller" -ForegroundColor White
        Write-Host "    - Click Next through all prompts" -ForegroundColor White
        Write-Host "    - Click Yes on network adapter warnings" -ForegroundColor White
        Write-Host "    - Click Install" -ForegroundColor White
        Write-Host "    - Then re-run this script to verify" -ForegroundColor White
    } catch {
        Write-Host "  [FAIL] Download failed: $_" -ForegroundColor Red
        Write-Host "  Please download manually from: https://www.virtualbox.org/wiki/Downloads" -ForegroundColor White
    }
}

# --- Step 5: Create tools directory ---
Write-Host "`n[5/5] Creating project directories..." -ForegroundColor Yellow

$dirs = @(
    "R:\Home SOC\Documentation\Screenshots",
    "R:\Home SOC\Configs",
    "R:\Home SOC\Scripts",
    "R:\Home SOC\Downloads"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  Exists: $dir" -ForegroundColor Gray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Phase 1 Script Complete!"               -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. If VirtualBox not installed: Install it now" -ForegroundColor White
Write-Host "  2. If Hyper-V was disabled: REBOOT your machine" -ForegroundColor White
Write-Host "  3. After reboot, run Phase 1 verification again" -ForegroundColor White
Write-Host "  4. Then proceed to Phase 2 (Kali Linux setup)" -ForegroundColor White
