# ============================================================
# PHASE 2-4 - VM Creation and Network Setup Script
# Run this AFTER VirtualBox is installed
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HOME SOC LAB - VM & Network Setup"      -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$vboxPath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

# Check if VirtualBox is installed
if (-not (Test-Path $vboxPath)) {
    Write-Host "[ERROR] VirtualBox not found at $vboxPath" -ForegroundColor Red
    Write-Host "Please install VirtualBox first (run Phase1 script)" -ForegroundColor Yellow
    exit 1
}

# --- Step 1: Configure Networking ---
Write-Host "`n[1/3] Configuring VirtualBox Networks..." -ForegroundColor Yellow

# Create Host-Only network
Write-Host "  Creating Host-Only adapter..." -ForegroundColor White
& $vboxPath hostonlyif create 2>&1 | Out-Null

# Get the host-only adapter name
$hostOnlyIf = (& $vboxPath list hostonlyifs | Select-String "Name:" | Select-Object -First 1).ToString().Split(":")[1].Trim()
Write-Host "  Host-Only Adapter: $hostOnlyIf" -ForegroundColor Green

# Configure host-only network
& $vboxPath hostonlyif ipconfig $hostOnlyIf --ip 192.168.56.1 --netmask 255.255.255.0
Write-Host "  [OK] Host-Only network configured (192.168.56.0/24)" -ForegroundColor Green

# Create NAT network
Write-Host "  Creating NAT network..." -ForegroundColor White
& $vboxPath natnetwork add --netname "SOC-NAT-Network" --network "10.0.2.0/24" --dhcp on --enable 2>&1 | Out-Null
Write-Host "  [OK] NAT network created (10.0.2.0/24)" -ForegroundColor Green

# --- Step 2: Download ISOs ---
Write-Host "`n[2/3] Downloading ISOs..." -ForegroundColor Yellow

$downloadDir = "R:\Home SOC\Downloads"
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
}

# Kali Linux ISO
$kaliIso = "$downloadDir\kali-linux-2024.4-installer-amd64.iso"
if (-not (Test-Path $kaliIso)) {
    Write-Host "  Downloading Kali Linux ISO (~4 GB)..." -ForegroundColor Yellow
    $kaliUrl = "https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-installer-amd64.iso"
    try {
        Invoke-WebRequest -Uri $kaliUrl -OutFile $kaliIso -UseBasicParsing
        Write-Host "  [OK] Kali ISO downloaded" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Auto-download failed. Please download manually:" -ForegroundColor Yellow
        Write-Host "    URL: https://www.kali.org/get-kali/" -ForegroundColor White
        Write-Host "    Save to: $kaliIso" -ForegroundColor White
    }
} else {
    Write-Host "  [OK] Kali ISO already exists" -ForegroundColor Green
}

# Windows 11 ISO (manual download required)
$winIso = "$downloadDir\WINDOWS_11_ENTERPRISE_EVAL_x64FRE_en-us.iso"
if (-not (Test-Path $winIso)) {
    Write-Host "  [ACTION] Windows 11 ISO must be downloaded manually:" -ForegroundColor Yellow
    Write-Host "    URL: https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise" -ForegroundColor White
    Write-Host "    Save to: $winIso" -ForegroundColor White
} else {
    Write-Host "  [OK] Windows 11 ISO already exists" -ForegroundColor Green
}

# --- Step 3: Create VMs ---
Write-Host "`n[3/3] Creating Virtual Machines..." -ForegroundColor Yellow

# Function to create VM
function Create-VM {
    param($name, $ostype, $ram, $cpus, $disk, $iso)

    Write-Host "  Creating VM: $name..." -ForegroundColor White

    # Create VM
    & $vboxPath createvm --name $name --ostype $ostype --register 2>&1 | Out-Null

    # Configure hardware
    & $vboxPath modifyvm $name --memory $ram --cpus $cpus --vram 128 --graphicscontroller vmsvga
    & $vboxPath modifyvm $name --firmware efi --boot1 dvd --boot2 disk

    # Create and attach disk
    $diskPath = "$env:USERPROFILE\VirtualBox VMs\$name\$name.vdi"
    & $vboxPath createmedium disk --filename $diskPath --size $disk 2>&1 | Out-Null
    & $vboxPath storagectl $name --name "SATA Controller" --add sata --controller IntelAhci
    & $vboxPath storageattach $name --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $diskPath

    # Attach ISO
    & $vboxPath storagectl $name --name "IDE Controller" --add ide
    & $vboxPath storageattach $name --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium $iso

    # Configure network
    & $vboxPath modifyvm $name --nic1 natnetwork --nat-network1 "SOC-NAT-Network"
    & $vboxPath modifyvm $name --nic2 hostonly --hostonlyadapter2 $hostOnlyIf

    Write-Host "  [OK] VM created: $name" -ForegroundColor Green
}

# Create Kali VM
$kaliName = "Kali-Linux-Attacker"
$existingVMs = & $vboxPath list vms
if ($existingVMs -notlike "*$kaliName*") {
    if (Test-Path $kaliIso) {
        Create-VM -name $kaliName -ostype "Debian_64" -ram 3072 -cpus 2 -disk 30720 -iso $kaliIso
    } else {
        Write-Host "  [SKIP] Kali ISO not found. Download it first." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [OK] Kali VM already exists" -ForegroundColor Green
}

# Create Windows VM
$winName = "Win11-Victim"
if ($existingVMs -notlike "*$winName*") {
    if (Test-Path $winIso) {
        Create-VM -name $winName -ostype "Windows11_64" -ram 4096 -cpus 2 -disk 51200 -iso $winIso
    } else {
        Write-Host "  [SKIP] Windows ISO not found. Download it first." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [OK] Windows VM already exists" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " VM & Network Setup Complete!"            -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next steps (MANUAL):" -ForegroundColor Yellow
Write-Host "  1. Open VirtualBox and verify VMs are created" -ForegroundColor White
Write-Host "  2. Start Kali VM and install Kali Linux:" -ForegroundColor White
Write-Host "     - Select 'Graphical Install'" -ForegroundColor White
Write-Host "     - Follow installation wizard" -ForegroundColor White
Write-Host "     - Set hostname: kali-attacker" -ForegroundColor White
Write-Host "     - Set username: kali, password: kali123" -ForegroundColor White
Write-Host "  3. Start Windows VM and install Windows 11:" -ForegroundColor White
Write-Host "     - Follow OOBE setup" -ForegroundColor White
Write-Host "     - Create local account: victim / Victim123!" -ForegroundColor White
Write-Host "  4. After OS installation, run Phase 5-8 scripts" -ForegroundColor White
