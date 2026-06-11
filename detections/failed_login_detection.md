# Failed Login Detection

## Overview

Detects brute force and credential stuffing attacks by monitoring for multiple failed authentication attempts from a single source.

## Detection Details

| Property | Value |
|----------|-------|
| **Detection ID** | SOC-DET-001 |
| **Severity** | High |
| **Tactics** | Credential Access |
| **Technique** | [T1110 - Brute Force](https://attack.mitre.org/techniques/T1110/) |
| **Data Source** | Windows Security Event Log |
| **Log Source** | `WinEventLog:Security` |
| **Event Code** | 4625 (An account failed to log on) |

## Description

This detection identifies potential brute force attacks by correlating failed login attempts. When a single source IP generates 5 or more failed logins within a 5-minute window, an alert is triggered.

### Attack Scenario

An attacker uses tools like Hydra or Medusa to attempt multiple password combinations against RDP (3389), SMB (445), or other authentication services.

**Example Attack:**
```bash
# From Kali Linux
hydra -l administrator -P /usr/share/wordlists/rockyou.txt rdp://192.168.56.20
```

## Detection Logic

### SPL Query

```spl
index=windows_events EventCode=4625
| stats count by IpAddress, TargetUserName, Workstation_Name
| where count >= 5
| sort -count
```

### Advanced Query with Time Window

```spl
index=windows_events EventCode=4625 earliest=-5m@m
| bucket _time span=5m
| stats count by IpAddress, TargetUserName, _time
| where count >= 5
| eval alert="Brute Force Detected"
| table _time, alert, IpAddress, TargetUserName, count
```

### Correlation with Successful Login

```spl
index=windows_events (EventCode=4625 OR EventCode=4624)
| eval status=if(EventCode=4625, "Failed", "Success")
| stats count(eval(status="Failed")) as Failed, count(eval(status="Success")) as Success by TargetUserName
| where Failed > 5 AND Success > 0
| eval risk="CRITICAL - Possible Compromise"
| table TargetUserName, Failed, Success, risk
```

## Expected Results

### Normal Activity

| Source IP | User | Failed Count | Result |
|-----------|------|--------------|--------|
| 192.168.56.1 | user1 | 2 | False positive (typos) |
| 10.0.2.15 | admin | 1 | Single typo |

### Attack Detected

| Source IP | User | Failed Count | Result |
|-----------|------|--------------|--------|
| 192.168.56.10 | administrator | 150 | **ALERT: Brute Force** |
| 192.168.56.10 | victim | 85 | **ALERT: Brute Force** |

## Alert Configuration

### Splunk Alert Setup

```spl
# Search
index=windows_events EventCode=4625 earliest=-5m@m
| stats count by IpAddress, TargetUserName
| where count >= 5

# Trigger Condition
# Number of Results > 0

# Schedule
# Run every 5 minutes
```

### Alert Actions

- **Email Notification:** Send to SOC team
- **Ticket Creation:** Create incident ticket
- **Dashboard Update:** Update Authentication Dashboard
- **Notable Event:** Create in Enterprise Security (if available)

## Investigation Steps

### 1. Validate the Alert

```spl
# Check for legitimate sources (domain controllers, service accounts)
index=windows_events EventCode=4625 IpAddress="192.168.56.10"
| table _time, TargetUserName, Logon_Type, Failure_Reason
```

### 2. Determine Scope

```spl
# How many accounts targeted?
index=windows_events EventCode=4625 IpAddress="192.168.56.10"
| stats dc(TargetUserName) as unique_accounts by IpAddress
```

### 3. Check for Success

```spl
# Did any login succeed after failures?
index=windows_events (EventCode=4625 OR EventCode=4624) TargetUserName="victim"
| eval status=if(EventCode=4625, "Failed", "Success")
| stats count by status
```

### 4. Identify Attack Vector

```spl
# What service was targeted?
index=windows_events EventCode=4625 IpAddress="192.168.56.10"
| stats count by Logon_Type
```

**Logon Type Reference:**
- 2 = Interactive (local console)
- 3 = Network (SMB, file share)
- 10 = Remote Interactive (RDP)
- 11 = Cached Interactive

## Response Actions

### Immediate (0-15 minutes)

1. **Verify alert** - Check if source IP is legitimate
2. **Identify target** - Which accounts were attacked?
3. **Check success** - Did any login succeed?
4. **Network containment** - Block attacker IP at firewall

### Short-term (15 min - 4 hours)

1. **Account review** - Reset passwords for targeted accounts
2. **Enable MFA** - If not already enabled
3. **Increase monitoring** - Add source IP to watchlist
4. **Forensic capture** - Save relevant logs

### Long-term (4+ hours)

1. **Root cause analysis** - How did attacker gain network access?
2. **Policy review** - Strengthen password policies
3. **Detection tuning** - Adjust thresholds if needed
4. **User training** - Educate on password security

## False Positives

### Common Scenarios

1. **Service accounts** with expired passwords
2. **Automated scripts** with incorrect credentials
3. **Domain replication** issues between DCs
4. **User typos** - Multiple incorrect password attempts

### Tuning

```spl
# Exclude known service accounts
index=windows_events EventCode=4625
| search NOT TargetUserName IN ("svc_backup", "svc_monitor")
| stats count by IpAddress
| where count >= 5
```

## Testing

### Generate Test Data

```bash
# From Kali - Generate failed logins
for i in {1..10}; do
  smbclient -L 192.168.56.20 -U victim%wrongpassword$i 2>/dev/null
done
```

### Verify Detection

```spl
# Check detection fired
index=windows_events EventCode=4625 IpAddress="192.168.56.10" earliest=-1h
| stats count
# Should be >= 10
```

## References

- [MITRE ATT&CK T1110](https://attack.mitre.org/techniques/T1110/)
- [Windows Event 4625](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/event-4625)
- [Splunk Security Essentials](https://docs.splunk.com/Documentation/SecurityEssentials/)

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2024-01-15 | 1.0 | SOC Team | Initial detection |
| 2024-02-01 | 1.1 | SOC Team | Added time window bucketing |
| 2024-03-10 | 1.2 | SOC Team | Added success correlation |
