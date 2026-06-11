# Incident Response Documentation

## Overview

This document provides structured incident response procedures for the Home SOC Lab, following the NIST SP 800-61 framework.

## Incident Response Lifecycle

```
┌─────────────┐
│ Preparation │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ Detection &     │
│ Analysis        │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Containment,    │
│ Eradication, &  │
│ Recovery        │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Post-Incident   │
│ Activity        │
└─────────────────┘
```

---

## Incident 1: Brute Force Attack

### Scenario

**Alert:** Multiple failed login attempts detected from 192.168.56.10

**Detection:**
```spl
index=windows_events EventCode=4625 IpAddress="192.168.56.10"
| stats count by TargetUserName
| where count >= 5
```

**Evidence:**
- 150 failed login attempts in 5 minutes
- Target accounts: victim, administrator
- Source: 192.168.56.10 (Kali Linux)

---

### Phase 1: Detection & Analysis

#### 1.1 Validate the Alert

**Check if source is legitimate:**
```spl
index=windows_events EventCode=4625 IpAddress="192.168.56.10" earliest=-1h
| table _time, TargetUserName, Logon_Type, Failure_Reason
| head 20
```

**Determine scope:**
```spl
# How many accounts targeted?
index=windows_events EventCode=4625 IpAddress="192.168.56.10"
| stats dc(TargetUserName) as unique_accounts

# What services attacked?
index=windows_events EventCode=4625 IpAddress="192.168.56.10"
| stats count by Logon_Type
```

**Logon Type Reference:**
- 2 = Interactive (local)
- 3 = Network (SMB)
- 10 = Remote Interactive (RDP)

#### 1.2 Check for Success

```spl
# Did any login succeed?
index=windows_events (EventCode=4625 OR EventCode=4624) TargetUserName="victim"
| eval status=if(EventCode=4625, "Failed", "Success")
| stats count by status
```

**Critical Finding:** If Success > 0 after failures, assume compromise!

#### 1.3 Timeline Reconstruction

```spl
# Create timeline
index=windows_events (EventCode=4625 OR EventCode=4624) IpAddress="192.168.56.10"
| table _time, EventCode, TargetUserName, Logon_Type
| sort _time
```

---

### Phase 2: Containment

#### Immediate Actions (0-15 minutes)

1. **Network Isolation**
   - Block source IP at firewall
   - Disable network adapter on victim VM if compromised
   - Document isolation time

2. **Account Lockdown**
   - Disable targeted accounts
   - Force password reset
   - Enable account lockout policy

3. **Preserve Evidence**
   - Capture memory dump
   - Export relevant logs
   - Screenshot alert details

#### Short-term Actions (15 min - 4 hours)

1. **Credential Reset**
   ```powershell
   # Reset password for compromised account
   net user victim NewSecurePassword123!
   ```

2. **Session Termination**
   ```powershell
   # Kill active RDP sessions
   query session
   logoff <session_id>
   ```

3. **Firewall Rules**
   ```powershell
   # Block attacker IP
   New-NetFirewallRule -DisplayName "Block Attacker" -RemoteAddress 192.168.56.10 -Action Block
   ```

---

### Phase 3: Eradication

#### 3.1 Remove Attacker Access

1. **Review Active Sessions**
   ```powershell
   # Check for active connections
   net session
   query user
   ```

2. **Check for Persistence**
   ```spl
   # Did attacker create scheduled tasks?
   index=sysmon_events EventCode=1 Image="*schtasks*" CommandLine="*/create*"
   | table _time, CommandLine
   
   # Did attacker create services?
   index=sysmon_events EventCode=1 Image="*sc.exe*" CommandLine="*create*"
   | table _time, CommandLine
   ```

3. **Remove Unauthorized Accounts**
   ```powershell
   # List all local users
   net user
   
   # Delete suspicious accounts
   net user malicioususer /delete
   ```

#### 3.2 Vulnerability Remediation

1. **Strengthen Password Policy**
   - Minimum length: 14 characters
   - Complexity requirements enabled
   - Account lockout: 5 failed attempts

2. **Enable MFA**
   - Configure RDP with MFA
   - Implement smart card authentication

3. **Network Hardening**
   - Restrict RDP access via firewall
   - Implement VPN requirement
   - Enable Network Level Authentication (NLA)

---

### Phase 4: Recovery

#### 4.1 System Restoration

1. **Verify System Integrity**
   ```powershell
   # Run system file checker
   sfc /scannow
   
   # Check for rootkits
   Get-MpThreatDetection
   ```

2. **Restore from Backup**
   - If system compromised, restore from clean backup
   - Rebuild VM if necessary

3. **Re-enable Services**
   - Gradually restore network access
   - Monitor for re-compromise

#### 4.2 Enhanced Monitoring

```spl
# Create watchlist for attacker IP
index=windows_events IpAddress="192.168.56.10"
| stats count

# Monitor targeted accounts
index=windows_events TargetUserName IN ("victim", "administrator")
| table _time, EventCode, IpAddress
```

---

### Phase 5: Post-Incident Activity

#### 5.1 Documentation

**Incident Report Template:**

```
INCIDENT REPORT
===============

Incident ID: IR-2024-001
Date/Time: 2024-01-15 14:30 UTC
Severity: High
Status: Closed

SUMMARY
-------
Brute force attack detected against Windows 11 VM from Kali Linux attacker.
150 failed login attempts in 5 minutes targeting RDP service.

TIMELINE
--------
14:30 - Alert triggered (150 failed logins)
14:32 - SOC analyst validated alert
14:35 - Network isolation implemented
14:40 - Attacker IP blocked
14:45 - Password reset completed
15:00 - Investigation concluded

INDICATORS OF COMPROMISE
-------------------------
Source IP: 192.168.56.10
Target IP: 192.168.56.20
Target Port: 3389 (RDP)
Target Accounts: victim, administrator
Failed Attempts: 150

ROOT CAUSE
----------
Weak password policy allowed brute force attack.
No MFA configured for RDP access.

REMEDIATION
-----------
1. Strengthened password policy (14 char minimum)
2. Enabled account lockout after 5 failures
3. Implemented firewall rules for RDP
4. Scheduled MFA implementation

LESSONS LEARNED
---------------
1. Detection rule effective (triggered within 2 minutes)
2. Response time acceptable (15 min to containment)
3. Need to improve prevention (MFA required)

RECOMMENDATIONS
---------------
1. Implement MFA for all remote access
2. Deploy VPN requirement for RDP
3. Enable advanced threat detection
4. Conduct quarterly penetration testing
```

#### 5.2 Detection Improvement

**Update detection rule:**
```spl
# Add correlation with successful login
index=windows_events (EventCode=4625 OR EventCode=4624)
| eval status=if(EventCode=4625, "Failed", "Success")
| stats count(eval(status="Failed")) as Failed, count(eval(status="Success")) as Success by TargetUserName
| where Failed > 5 AND Success > 0
| eval risk="CRITICAL - Possible Compromise"
```

#### 5.3 Process Refinement

**Update incident response playbook:**
- Add specific steps for credential attacks
- Include account lockout procedures
- Document MFA emergency bypass

---

## Incident 2: Port Scan Detected

### Scenario

**Alert:** Network reconnaissance detected from 192.168.56.10

**Detection:**
```spl
index=sysmon_events EventCode=3 SourceIp="192.168.56.10"
| stats dc(DestinationPort) as unique_ports
| where unique_ports >= 15
```

**Evidence:**
- 50 unique ports scanned
- Target: 192.168.56.20
- Tool: Nmap

---

### Response Procedure

#### Detection & Analysis

```spl
# Identify scan type
index=sysmon_events EventCode=3 SourceIp="192.168.56.10"
| stats count by DestinationPort
| sort DestinationPort

# Check for follow-up activity
index=sysmon_events EventCode=3 SourceIp="192.168.56.10" Initiated=true
| search DestinationPort IN (22, 445, 3389)
| table _time, DestinationPort, Image
```

#### Containment

1. **Block Source**
   ```powershell
   New-NetFirewallRule -DisplayName "Block Scanner" -RemoteAddress 192.168.56.10 -Action Block
   ```

2. **Review Exposed Services**
   ```powershell
   # Check listening ports
   netstat -ano | findstr LISTENING
   ```

3. **Disable Unnecessary Services**
   ```powershell
   # Disable SMBv1
   Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
   ```

#### Eradication

1. **Service Hardening**
   - Disable unused services
   - Configure firewall for least privilege
   - Enable Windows Firewall logging

2. **Network Segmentation**
   - Implement VLANs
   - Restrict lateral movement
   - Deploy network monitoring

#### Recovery

1. **Gradual Re-enablement**
   - Restore necessary services
   - Monitor for re-scanning
   - Validate firewall rules

#### Post-Incident

**Update detection:**
```spl
# Add horizontal scan detection
index=sysmon_events EventCode=3
| stats dc(DestinationIp) as unique_hosts by SourceIp, DestinationPort
| where unique_hosts >= 10
```

---

## Incident 3: PowerShell Attack

### Scenario

**Alert:** Encoded PowerShell command detected

**Detection:**
```spl
index=sysmon_events EventCode=1 CommandLine="*-enc*"
```

**Evidence:**
- Base64 encoded command
- Process: powershell.exe
- User: victim

---

### Response Procedure

#### Detection & Analysis

1. **Decode Command**
   ```spl
   index=sysmon_events EventCode=1 CommandLine="*-enc*"
   | rex field=CommandLine "-enc\s+(?<encoded>[^\s]+)"
   | eval decoded=base64decode(encoded)
   | table _time, decoded, User
   ```

2. **Identify Parent Process**
   ```spl
   index=sysmon_events EventCode=1 Image="*powershell*"
   | table _time, ParentImage, CommandLine
   ```

3. **Check for Downloads**
   ```spl
   index=sysmon_events EventCode=11 Image="*powershell*"
   | table _time, TargetFilename
   ```

#### Containment

1. **Kill Process**
   ```powershell
   # Find and kill PowerShell
   Get-Process powershell | Stop-Process -Force
   ```

2. **Network Isolation**
   - Disable network adapter
   - Block outbound connections

3. **File Quarantine**
   - Isolate downloaded files
   - Hash and submit to VirusTotal

#### Eradication

1. **Malware Removal**
   ```powershell
   # Run full AV scan
   Start-MpScan -ScanType FullScan
   ```

2. **Remove Persistence**
   ```spl
   # Check for scheduled tasks
   index=sysmon_events EventCode=1 Image="*schtasks*"
   ```

3. **Credential Reset**
   - Reset user password
   - Revoke active tokens

#### Recovery

1. **System Validation**
   - Verify no rootkits
   - Check startup items
   - Validate system files

2. **PowerShell Hardening**
   ```powershell
   # Enable Constrained Language Mode
   $ExecutionContext.SessionState.LanguageMode = "ConstrainedLanguage"
   
   # Enable AppLocker
   # (Configure via Group Policy)
   ```

#### Post-Incident

1. **Implement PowerShell Logging**
   - Script Block Logging
   - Module Logging
   - Transcription

2. **Deploy AppLocker**
   - Restrict PowerShell execution
   - Whitelist approved scripts

---

## Incident Response Tools

### Built-in Windows Tools

```powershell
# Process monitoring
Get-Process
tasklist

# Network connections
netstat -ano
Get-NetTCPConnection

# Event logs
Get-WinEvent -LogName Security
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational"

# User sessions
query user
qwinsta

# Services
Get-Service
sc query
```

### Sysinternals Suite

```powershell
# Process Explorer (GUI)
procexp.exe

# Autoruns (persistence)
autoruns.exe

# TCPView (network)
tcpview.exe

# Process Monitor (file/registry)
procmon.exe
```

### Splunk Queries

```spl
# Real-time monitoring
index=* earliest=now
| head 100

# Process tree
index=sysmon_events EventCode=1
| table _time, ProcessId, ParentProcessId, Image, CommandLine

# Network connections
index=sysmon_events EventCode=3
| table _time, SourceIp, DestinationIp, DestinationPort, Image
```

---

## Communication Plan

### Internal Notifications

**Severity Levels:**

| Level | Response Time | Notification |
|-------|---------------|--------------|
| Critical | 15 minutes | Phone call + Email |
| High | 1 hour | Email + Slack |
| Medium | 4 hours | Email |
| Low | 24 hours | Ticket |

### External Communications

**Law Enforcement:**
- Contact if criminal activity suspected
- Preserve chain of custody
- Document all evidence

**Regulatory:**
- Notify if PII/PHI compromised
- Follow breach notification laws
- Document notification timeline

**Customers/Partners:**
- Notify if their data affected
- Provide incident summary
- Offer support resources

---

## Incident Response Kit

### Hardware

- Write blockers
- External drives (1TB+)
- Network tap
- Bootable USB drives

### Software

- FTK Imager (disk imaging)
- Volatility (memory analysis)
- Wireshark (packet capture)
- Autopsy (forensics)

### Documentation

- Incident response playbook
- Contact list
- Evidence collection forms
- Chain of custody forms

---

## Training and Exercises

### Tabletop Exercises

**Scenario 1: Ransomware Attack**
- Walkthrough detection and containment
- Test backup restoration
- Evaluate communication plan

**Scenario 2: Data Breach**
- Identify scope of compromise
- Practice regulatory notification
- Test customer communication

### Red Team Exercises

**Quarterly:**
- Simulate real-world attacks
- Test detection capabilities
- Measure response times

**Annual:**
- Full penetration test
- External assessment
- Compliance validation

---

## Metrics and KPIs

### Detection Metrics

- Mean Time to Detect (MTTD)
- False positive rate
- Detection coverage (%)

### Response Metrics

- Mean Time to Respond (MTTR)
- Mean Time to Contain (MTTC)
- Incident volume by type

### Quality Metrics

- Repeat incidents
- Escalation rate
- Customer satisfaction

---

## References

- [NIST SP 800-61](https://csrc.nist.gov/publications/detail/sp/800-61/rev-2/final)
- [SANS Incident Response](https://www.sans.org/incident-response/)
- [FIRST Incident Response](https://www.first.org/)

---

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2024-01-20 | 1.0 | SOC Team | Initial documentation |
| 2024-02-15 | 1.1 | SOC Team | Added PowerShell incident |
| 2024-03-10 | 1.2 | SOC Team | Added communication plan |
