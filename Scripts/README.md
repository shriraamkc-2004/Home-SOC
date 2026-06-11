# HOME SOC LAB - Automation Scripts

These PowerShell scripts automate the installation and configuration of your Home SOC Lab.

## Prerequisites

- **Windows 11** as host OS
- **Administrator privileges** for all scripts
- **Internet connection** for downloads

## Scripts Overview

| Script | Purpose | Where to Run |
|--------|---------|--------------|
| `Phase1_SystemPrep.ps1` | Check hardware, virtualization, install VirtualBox | Host machine |
| `Phase2-4_VMSetup.ps1` | Create VMs, configure networks, download ISOs | Host machine |
| `Phase5-7_WindowsVMSetup.ps1` | Configure Windows VM (IP, Sysmon, Forwarder) | **Inside Windows VM** |
| `Phase6-8_SplunkSetup.ps1` | Install and configure Splunk server | Host machine |

## Execution Order

### Step 1: System Preparation (Host)

```powershell
# Open PowerShell as Administrator
cd "R:\Home SOC\Scripts"
.\Phase1_SystemPrep.ps1
```

**What it does:**
- Checks CPU, RAM, disk space
- Verifies virtualization is enabled
- Checks/disables Hyper-V if needed
- Downloads VirtualBox if not installed
- Creates project directories

**Manual steps after running:**
- If Hyper-V was disabled → **REBOOT** your machine
- If VirtualBox downloaded → **Run the installer** manually
- After reboot, re-run Phase1 to verify

---

### Step 2: VM and Network Setup (Host)

```powershell
# After VirtualBox is installed
.\Phase2-4_VMSetup.ps1
```

**What it does:**
- Creates Host-Only network (192.168.56.0/24)
- Creates NAT network (10.0.2.0/24)
- Downloads Kali Linux ISO (~4 GB)
- Creates Kali and Windows VMs with correct settings
- Attaches ISOs to VMs

**Manual steps after running:**
1. **Install Kali Linux:**
   - Open VirtualBox → Start Kali VM
   - Select "Graphical Install"
   - Follow wizard: hostname=`kali-attacker`, user=`kali`, password=`kali123`
   - Use entire disk, install GRUB
   - Wait for reboot

2. **Install Windows 11:**
   - Start Windows VM
   - Follow OOBE setup
   - Create local account: `victim` / `Victim123!`
   - Complete Windows setup

3. **Install Guest Additions on both VMs:**
   - In each VM: Devices → Insert Guest Additions CD
   - Run installer, reboot

---

### Step 3: Windows VM Configuration (Inside VM)

```powershell
# Inside the Windows Victim VM
# Open PowerShell as Administrator

# Copy the script to the VM (shared folder, drag-drop, or network)
cd C:\Scripts  # or wherever you copy it
.\Phase5-7_WindowsVMSetup.ps1
```

**What it does:**
- Sets static IP: 192.168.56.20
- Enables Remote Desktop
- Disables Windows Defender (lab only!)
- Downloads and installs Sysmon with config
- Enables PowerShell logging
- Installs Splunk Universal Forwarder
- Configures log forwarding to Splunk

**Manual steps:**
- If Splunk UF installer not found → Download it manually
- Verify connectivity: `ping 192.168.56.1` (host) and `ping 192.168.56.10` (Kali)

---

### Step 4: Splunk Server Setup (Host)

```powershell
# On host machine
.\Phase6-8_SplunkSetup.ps1
```

**What it does:**
- Checks if Splunk is installed
- Enables receiving port 9997
- Creates custom indexes (windows_events, sysmon_events, etc.)
- Opens Splunk Web in browser

**Manual steps:**
- If Splunk not installed → Download and install manually
- Login to Splunk Web (admin / SOCadmin123!)
- Install Splunk Add-ons:
  - Apps → Find More Apps → Search "Windows"
  - Install: **Splunk Add-on for Microsoft Windows**
  - Install: **Splunk Add-on for Sysmon**

---

## After Automation Completes

Once all scripts run successfully, your lab is ready for:

### Phase 9: Attack Simulations
See `Home_SOC_Lab_Guide.md` for detailed attack scenarios:
- Nmap port scans (from Kali)
- Brute force attacks (from Kali)
- PowerShell monitoring (on Windows VM)
- Suspicious process detection (on Windows VM)

### Phase 10: Dashboards
Create dashboards in Splunk Web:
- Authentication Dashboard
- Threat Detection Dashboard
- Endpoint Activity Dashboard
- Network Activity Dashboard

All SPL queries are in `Home_SOC_Lab_Guide.md`

### Phase 11: Alerts
Configure alerts in Splunk Web for:
- Brute force login attempts
- Suspicious PowerShell execution
- Port scan detection
- LOLBAS activity

### Phase 12: Documentation
Take screenshots at each step and document your findings.

---

## Troubleshooting

### VirtualBox VM won't start
```powershell
# Disable Hyper-V completely
bcdedit /set hypervisorlaunchtype off
# Reboot
```

### Can't ping between VMs
```powershell
# On Windows VM - Allow ICMP
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 -Action Allow
```

### Splunk not receiving logs
```powershell
# Check forwarder connection (on Windows VM)
& "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" list forward-server -auth admin:changeme

# Check Splunk is listening (on host)
& "C:\Program Files\Splunk\bin\splunk.exe" display listen
```

### Sysmon not generating events
```powershell
# Check service
Get-Service Sysmon64

# Reinstall if needed
& "C:\Tools\Sysmon\Sysmon64.exe" -u
& "C:\Tools\Sysmon\Sysmon64.exe" -accepteula -i "C:\Tools\Sysmon\sysmonconfig-export.xml"
```

---

## Network Configuration Summary

| Machine | Host-Only IP | NAT IP | Purpose |
|---------|--------------|--------|---------|
| Host (Win 11) | 192.168.56.1 | DHCP | Splunk Server |
| Kali Linux | 192.168.56.10 | DHCP | Attacker |
| Windows Victim | 192.168.56.20 | DHCP | Victim + Forwarder |

**Host-Only Network:** 192.168.56.0/24 (VM-to-VM communication)  
**NAT Network:** 10.0.2.0/24 (Internet access)

---

## Important URLs

- **Splunk Web:** https://localhost:8000
- **Splunk Docs:** https://docs.splunk.com/
- **Sysmon Config:** https://github.com/SwiftOnSecurity/sysmon-config
- **MITRE ATT&CK:** https://attack.mitre.org/

---

## Support

For detailed step-by-step instructions, see the complete guide:  
**`R:\Home SOC\Home_SOC_Lab_Guide.md`**

Good luck building your SOC lab!
