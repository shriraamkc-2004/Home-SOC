# 🛡️ Home SOC Lab - Security Operations Center

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Splunk](https://img.shields.io/badge/Splunk-Enterprise-orange.svg)](https://www.splunk.com/)
[![Sysmon](https://img.shields.io/badge/Sysmon-15.x-blue.svg)](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon)
[![MITRE ATT&CK](https://img.shields.io/badge/MITRE%20ATT%26CK-Mapped-red.svg)](https://attack.mitre.org/)
[![Windows](https://img.shields.io/badge/Windows-11-0078D6.svg)](https://www.microsoft.com/windows)
[![Kali Linux](https://img.shields.io/badge/Kali-Linux-557C94.svg)](https://www.kali.org/)
[![VirtualBox](https://img.shields.io/badge/VirtualBox-7.x-183A61.svg)](https://www.virtualbox.org/)

A comprehensive Security Operations Center (SOC) lab built on a single laptop, demonstrating enterprise-grade threat detection, log analysis, and incident response capabilities.

![SOC Lab Architecture](screenshots/architecture-diagram.png)

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Technologies Used](#-technologies-used)
- [Installation](#-installation)
- [Attack Simulations](#-attack-simulations)
- [Detection Rules](#-detection-rules)
- [Dashboards](#-dashboards)
- [MITRE ATT&CK Mapping](#-mitre-attck-mapping)
- [Incident Response Workflow](#-incident-response-workflow)
- [Future Enhancements](#-future-enhancements)
- [Author](#-author)

## 🎯 Project Overview

This Home SOC Lab replicates a real-world Security Operations Center environment using virtualization. It demonstrates:

- **Attack Simulation** - Red team techniques using Kali Linux
- **Log Collection** - Centralized logging with Splunk Enterprise
- **Endpoint Monitoring** - Advanced telemetry with Sysmon
- **Threat Detection** - Custom detection rules and alerts
- **Incident Response** - Structured investigation workflows
- **Security Analytics** - Interactive dashboards and reporting

**Lab Environment:**
- Host: Windows 11
- Attacker VM: Kali Linux (192.168.56.10)
- Victim VM: Windows 11 (192.168.56.20)
- SIEM: Splunk Enterprise Free Edition
- Endpoint Agent: Sysmon + Splunk Universal Forwarder

## ✨ Features

### Threat Detection
- **Brute Force Detection** - Identify credential stuffing attacks
- **Port Scan Detection** - Detect network reconnaissance
- **PowerShell Monitoring** - Track encoded commands and execution
- **Suspicious Process Detection** - LOLBAS and living-off-the-land techniques
- **Reverse Shell Detection** - Identify command and control channels

### Security Monitoring
- Real-time log collection from Windows endpoints
- Process creation and termination tracking
- Network connection monitoring
- File system change detection
- Registry modification alerts
- DNS query logging

### Analytics & Visualization
- Authentication Dashboard - Login success/failure analysis
- Threat Dashboard - Attack pattern visualization
- Endpoint Dashboard - Process and file activity monitoring
- Network Dashboard - Traffic analysis and anomaly detection

### Incident Response
- Structured investigation workflows
- Timeline reconstruction
- IOC (Indicator of Compromise) extraction
- Containment and eradication procedures

## 🏗️ Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                    HOST: Windows 11                          │
│                     192.168.56.1                             │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              VirtualBox / VMware                        │ │
│  │                                                         │ │
│  │  ┌──────────────┐  Host-Only   ┌──────────────────┐   │ │
│  │  │  Kali Linux  │◄────────────►│  Windows 11 VM   │   │ │
│  │  │  (Attacker)  │  192.168.56.x │  (Victim)        │   │ │
│  │  │  192.168.56.10│              │  192.168.56.20   │   │ │
│  │  └──────────────┘              └────────┬─────────┘   │ │
│  │         │                               │              │ │
│  │         │      NAT Network              │              │ │
│  │         │      (Internet)               │              │ │
│  │         ▼                               ▼              │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │           Splunk Enterprise (Host)                │  │ │
│  │  │           Port 8000 (Web) / 9997 (Forwarding)     │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Windows VM (Victim)
    ↓
Sysmon (Process, Network, File Events)
    ↓
Splunk Universal Forwarder
    ↓ Port 9997
Splunk Enterprise (Host)
    ↓
Indexes: windows_events, sysmon_events, powershell_logs
    ↓
Search & Reporting App
    ↓
Dashboards & Alerts
```

For detailed architecture documentation, see [Architecture Documentation](architecture/README.md).

## 🛠️ Technologies Used

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Virtualization** | VirtualBox 7.x | VM hosting and network isolation |
| **Attacker OS** | Kali Linux 2024.4 | Red team tools and attack simulation |
| **Victim OS** | Windows 11 Enterprise | Target system for attacks |
| **Endpoint Monitoring** | Sysmon 15.x | Advanced Windows telemetry |
| **SIEM** | Splunk Enterprise 9.x | Log aggregation and analysis |
| **Log Forwarder** | Splunk Universal Forwarder | Endpoint log collection |
| **Detection Framework** | Splunk SPL | Custom detection rules |
| **Threat Framework** | MITRE ATT&CK | Attack technique mapping |

## 🚀 Installation

### Prerequisites

- Windows 11 (or Linux/macOS with virtualization support)
- 16 GB RAM minimum (24+ GB recommended)
- 100 GB free disk space
- CPU with VT-x/AMD-V enabled

### Quick Start

1. **System Preparation**
   ```powershell
   # Run as Administrator
   cd "Scripts"
   .\Phase1_SystemPrep.ps1
   ```

2. **VM Creation**
   ```powershell
   .\Phase2-4_VMSetup.ps1
   ```

3. **Install Operating Systems**
   - Start Kali VM → Install Kali Linux
   - Start Windows VM → Install Windows 11

4. **Configure Windows VM**
   ```powershell
   # Inside Windows VM as Administrator
   .\Phase5-7_WindowsVMSetup.ps1
   ```

5. **Setup Splunk Server**
   ```powershell
   # On host machine
   .\Phase6-8_SplunkSetup.ps1
   ```

For detailed installation instructions, see [Installation Guide](docs/INSTALLATION.md).

## ⚔️ Attack Simulations

### Scenario 1: Brute Force Attack

**Objective:** Detect credential stuffing against RDP/SMB

**Attack (Kali):**
```bash
hydra -l victim -P /tmp/passwords.txt rdp://192.168.56.20 -t 4 -V
```

**Detection:**
```spl
index=windows_events EventCode=4625
| stats count by IpAddress, TargetUserName
| where count >= 5
```

**MITRE ATT&CK:** [T1110 - Brute Force](https://attack.mitre.org/techniques/T1110/)

### Scenario 2: Port Scanning

**Objective:** Detect network reconnaissance

**Attack (Kali):**
```bash
nmap -sS -sV -O 192.168.56.20
```

**Detection:**
```spl
index=sysmon_events EventCode=3
| stats dc(DestinationPort) as UniquePorts by SourceIp
| where UniquePorts >= 15
```

**MITRE ATT&CK:** [T1046 - Network Service Discovery](https://attack.mitre.org/techniques/T1046/)

### Scenario 3: PowerShell Attack

**Objective:** Detect encoded PowerShell commands

**Attack (Windows VM):**
```powershell
$cmd = "Get-Process"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
powershell.exe -EncodedCommand $encoded
```

**Detection:**
```spl
index=sysmon_events EventCode=1
| search CommandLine="*-enc*" OR CommandLine="*-EncodedCommand*"
```

**MITRE ATT&CK:** [T1059.001 - PowerShell](https://attack.mitre.org/techniques/T1059/001/)

### Scenario 4: LOLBAS Techniques

**Objective:** Detect living-off-the-land binaries

**Attack:**
```powershell
certutil.exe -urlcache -split -f "http://example.com/test.txt" test.txt
```

**Detection:**
```spl
index=sysmon_events EventCode=1
| search Image="*certutil*" CommandLine="*urlcache*"
```

**MITRE ATT&CK:** [T1105 - Ingress Tool Transfer](https://attack.mitre.org/techniques/T1105/)

For complete attack scenarios, see [Attack Simulations](docs/ATTACK_SIMULATIONS.md).

## 🎯 Detection Rules

All detection rules are documented in the [detections/](detections/) directory:

- [Failed Login Detection](detections/failed_login_detection.md)
- [Port Scan Detection](detections/port_scan_detection.md)
- [PowerShell Detection](detections/powershell_detection.md)
- [Suspicious Process Detection](detections/suspicious_process_detection.md)
- [Reverse Shell Detection](detections/reverse_shell_detection.md)

Each rule includes:
- Description and use case
- SPL query
- Expected results
- MITRE ATT&CK mapping
- Alert configuration

## 📊 Dashboards

### Authentication Dashboard
![Authentication Dashboard](screenshots/dashboard-authentication.png)

Monitors login attempts, account lockouts, and brute force activity.

### Threat Detection Dashboard
![Threat Dashboard](screenshots/dashboard-threat.png)

Tracks suspicious processes, LOLBAS usage, and process injection attempts.

### Endpoint Activity Dashboard
![Endpoint Dashboard](screenshots/dashboard-endpoint.png)

Visualizes process creation, file modifications, and registry changes.

### Network Activity Dashboard
![Network Dashboard](screenshots/dashboard-network.png)

Analyzes network connections, port scans, and outbound traffic.

For dashboard configurations and SPL queries, see [Dashboard Documentation](dashboards/README.md).

## 🗺️ MITRE ATT&CK Mapping

| Technique ID | Technique Name | Detection Logic |
|--------------|----------------|-----------------|
| T1110 | Brute Force | Multiple EventCode 4625 from same source |
| T1046 | Network Service Discovery | High unique port count from single IP |
| T1059.001 | PowerShell | Encoded commands, execution policy bypass |
| T1105 | Ingress Tool Transfer | certutil, bitsadmin, mshta usage |
| T1055 | Process Injection | CreateRemoteThread, LSASS access |
| T1053.005 | Scheduled Task | schtasks.exe /create |
| T1543.003 | Windows Service | sc.exe create, New-Service |

Full mapping available in [MITRE ATT&CK Documentation](mitre_attack_mapping/README.md).

## 🔍 Incident Response Workflow

### Phase 1: Detection
- Alert triggered in Splunk
- SOC analyst triages event
- Determines if true positive

### Phase 2: Analysis
- Timeline reconstruction
- Scope determination
- IOC extraction (IPs, hashes, processes)

### Phase 3: Containment
- Network isolation (disable adapter)
- Process termination
- Account disablement

### Phase 4: Eradication
- Malware removal
- Persistence mechanism cleanup
- Vulnerability patching

### Phase 5: Recovery
- System restoration
- Monitoring enhancement
- Return to production

### Phase 6: Lessons Learned
- Documentation
- Detection rule improvement
- Process refinement

For detailed IR playbooks, see [Incident Response Documentation](docs/INCIDENT_RESPONSE.md).

## 🔮 Future Enhancements

- [ ] **Active Directory Integration** - Domain controller for Kerberos attacks
- [ ] **ELK Stack** - Alternative open-source SIEM
- [ ] **Wazuh** - Open-source EDR/XDR platform
- [ ] **TheHive** - Case management and collaboration
- [ ] **MISP** - Threat intelligence platform
- [ ] **Velociraptor** - Advanced DFIR tool
- [ ] **Atomic Red Team** - Automated attack simulation
- [ ] **Sigma Rules** - Generic detection rule format
- [ ] **SOAR Integration** - Automated response workflows
- [ ] **Grafana** - Additional visualization layer

## 👤 Author

**Your Name**  
Cybersecurity Enthusiast | SOC Analyst | Blue Team

- 📧 Email: your.email@example.com
- 💼 LinkedIn: [linkedin.com/in/yourprofile](https://linkedin.com/in/yourprofile)
- 🐙 GitHub: [github.com/yourusername](https://github.com/yourusername)
- 📝 Blog: [yourblog.com](https://yourblog.com)

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Splunk](https://www.splunk.com/) - SIEM platform
- [Sysmon](https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon) - System monitoring
- [MITRE ATT&CK](https://attack.mitre.org/) - Threat framework
- [SwiftOnSecurity](https://github.com/SwiftOnSecurity/sysmon-config) - Sysmon configuration
- [Kali Linux](https://www.kali.org/) - Penetration testing distribution

## 📚 Resources

- [Splunk Documentation](https://docs.splunk.com/)
- [MITRE ATT&CK](https://attack.mitre.org/)
- [LOLBAS Project](https://lolbas-project.github.io/)
- [Sigma Rules](https://github.com/SigmaHQ/sigma)
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)

---

**⭐ If you find this project helpful, please give it a star!**

**🔔 Follow for more cybersecurity projects and tutorials!**
