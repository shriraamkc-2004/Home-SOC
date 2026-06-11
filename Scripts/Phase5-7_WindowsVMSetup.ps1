# ============================================================
# PHASE 5-7 - Windows VM Configuration Script
# Run this INSIDE the Windows Victim VM as Administrator
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HOME SOC LAB - Windows VM Setup"        -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- Step 1: Configure Static IP ---
Write-Host "`n[1/6] Configuring Static IP..." -ForegroundColor Yellow

$adapter = Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*VirtualBox Host-Only*"}
if ($adapter) {
    $adapterName = $adapter.Name
    Write-Host "  Found Host-Only adapter: $adapterName" -ForegroundColor Green

    # Remove existing IP
    Remove-NetIPAddress -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue

    # Set static IP
    New-NetIPAddress -InterfaceAlias $adapterName -IPAddress 192.168.56.20 -PrefixLength 24 -ErrorAction SilentlyContinue
    Write-Host "  [OK] Static IP set: 192.168.56.20" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Host-Only adapter not found" -ForegroundColor Yellow
    Write-Host "  Please ensure Adapter 2 is configured as Host-Only in VirtualBox" -ForegroundColor White
}

# Set DNS on NAT adapter
$natAdapter = Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*VirtualBox*NAT*" -or $_.InterfaceDescription -like "*Intel*PRO*"}
if ($natAdapter) {
    Set-DnsClientServerAddress -InterfaceAlias $natAdapter.Name -ServerAddresses ("8.8.8.8","8.8.4.4")
    Write-Host "  [OK] DNS configured on NAT adapter" -ForegroundColor Green
}

# --- Step 2: Enable Remote Desktop ---
Write-Host "`n[2/6] Enabling Remote Desktop..." -ForegroundColor Yellow

Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Host "  [OK] Remote Desktop enabled" -ForegroundColor Green

# --- Step 3: Disable Windows Defender (LAB ONLY) ---
Write-Host "`n[3/6] Disabling Windows Defender (LAB ONLY)..." -ForegroundColor Yellow

try {
    Set-MpPreference -DisableRealtimeMonitoring $true
    Write-Host "  [OK] Real-time protection disabled" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Could not disable Defender (Tamper Protection may be on)" -ForegroundColor Yellow
    Write-Host "  Manual: Settings → Privacy & Security → Windows Security → Virus & threat protection" -ForegroundColor White
    Write-Host "          → Manage settings → Turn OFF Real-time protection" -ForegroundColor White
}

# Disable firewall for testing
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Write-Host "  [OK] Firewall disabled (lab only)" -ForegroundColor Green

# Allow ICMP
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 -Action Allow -ErrorAction SilentlyContinue
Write-Host "  [OK] ICMP allowed" -ForegroundColor Green

# --- Step 4: Install Sysmon ---
Write-Host "`n[4/6] Installing Sysmon..." -ForegroundColor Yellow

$sysmonDir = "C:\Tools\Sysmon"
New-Item -ItemType Directory -Path $sysmonDir -Force | Out-Null

# Download Sysmon
$sysmonZip = "$sysmonDir\Sysmon.zip"
if (-not (Test-Path $sysmonZip)) {
    Write-Host "  Downloading Sysmon..." -ForegroundColor White
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile $sysmonZip
}

# Extract
Expand-Archive -Path $sysmonZip -DestinationPath $sysmonDir -Force

# Download SwiftOnSecurity config
$configFile = "$sysmonDir\sysmonconfig-export.xml"
if (-not (Test-Path $configFile)) {
    Write-Host "  Downloading Sysmon config..." -ForegroundColor White
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile $configFile
}

# Install Sysmon
$sysmonExe = "$sysmonDir\Sysmon64.exe"
if (Test-Path $sysmonExe) {
    & $sysmonExe -accepteula -i $configFile
    Start-Sleep -Seconds 3

    # Verify
    $service = Get-Service Sysmon64 -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Write-Host "  [OK] Sysmon installed and running" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Sysmon service not running" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [FAIL] Sysmon64.exe not found" -ForegroundColor Red
}

# --- Step 5: Enable PowerShell Logging ---
Write-Host "`n[5/6] Enabling PowerShell Logging..." -ForegroundColor Yellow

# Script Block Logging
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Type DWord

# Module Logging
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -Value 1 -Type DWord

# Transcription
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "OutputDirectory" -Value "C:\PSTranscripts" -Type String
New-Item -Path "C:\PSTranscripts" -Force | Out-Null

Write-Host "  [OK] PowerShell logging enabled" -ForegroundColor Green

# --- Step 6: Install Splunk Universal Forwarder ---
Write-Host "`n[6/6] Installing Splunk Universal Forwarder..." -ForegroundColor Yellow

$ufDir = "C:\Program Files\SplunkUniversalForwarder"
if (Test-Path $ufDir) {
    Write-Host "  [OK] Universal Forwarder already installed" -ForegroundColor Green
} else {
    $ufInstaller = "$env:USERPROFILE\Downloads\splunkforwarder.msi"

    if (-not (Test-Path $ufInstaller)) {
        Write-Host "  [ACTION] Download Splunk Universal Forwarder:" -ForegroundColor Yellow
        Write-Host "    URL: https://www.splunk.com/en_us/download/universal-forwarder.html" -ForegroundColor White
        Write-Host "    Save to: $ufInstaller" -ForegroundColor White
        Write-Host "  Then re-run this script." -ForegroundColor White
    } else {
        Write-Host "  Installing Universal Forwarder..." -ForegroundColor White

        # Silent install
        $installArgs = "/i `"$ufInstaller`" AGREETOLICENSE=Yes RECEIVING_INDEXER=`"192.168.56.1:9997`" WINEVENTLOG_APP_ENABLE=1 WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 LAUNCHSPLUNK=1 /quiet"
        Start-Process msiexec.exe -ArgumentList $installArgs -Wait

        # Verify
        $ufService = Get-Service SplunkForwarder -ErrorAction SilentlyContinue
        if ($ufService -and $ufService.Status -eq "Running") {
            Write-Host "  [OK] Universal Forwarder installed and running" -ForegroundColor Green

            # Add Sysmon monitoring
            Write-Host "  Configuring Sysmon log forwarding..." -ForegroundColor White
            & "$ufDir\bin\splunk.exe" add monitor "WinEventLog://Microsoft-Windows-Sysmon/Operational" -index sysmon_events -auth admin:changeme

            # Add PowerShell monitoring
            & "$ufDir\bin\splunk.exe" add monitor "WinEventLog://Microsoft-Windows-PowerShell/Operational" -index powershell_logs -auth admin:changeme

            # Restart forwarder
            & "$ufDir\bin\splunk.exe" restart
            Write-Host "  [OK] Log forwarding configured" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Universal Forwarder not running" -ForegroundColor Red
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Windows VM Setup Complete!"              -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification:" -ForegroundColor Yellow
Write-Host "  1. Check IP: ipconfig" -ForegroundColor White
Write-Host "  2. Test ping to host: ping 192.168.56.1" -ForegroundColor White
Write-Host "  3. Test ping to Kali: ping 192.168.56.10" -ForegroundColor White
Write-Host "  4. Check Sysmon: Get-Service Sysmon64" -ForegroundColor White
Write-Host "  5. Check Forwarder: Get-Service SplunkForwarder" -ForegroundColor White
