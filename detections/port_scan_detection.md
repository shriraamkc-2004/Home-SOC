# Port Scan Detection

## Overview

Detects network reconnaissance and port scanning activity by identifying sources connecting to multiple destination ports.

## Detection Details

| Property | Value |
|----------|-------|
| **Detection ID** | SOC-DET-002 |
| **Severity** | Medium |
| **Tactics** | Discovery |
| **Technique** | [T1046 - Network Service Discovery](https://attack.mitre.org/techniques/T1046/) |
| **Data Source** | Sysmon Event Log |
| **Log Source** | `Microsoft-Windows-Sysmon/Operational` |
| **Event Code** | 3 (Network connection detected) |

## Description

This detection identifies potential port scanning by monitoring for single source IPs connecting to 15 or more unique destination ports within a 5-minute window. Port scanning is typically the first step in an attack chain to identify running services.

### Attack Scenario

An attacker uses Nmap or similar tools to discover open ports and services on target systems.

**Example Attacks:**
```bash
# SYN scan (stealth)
nmap -sS 192.168.56.20

# Service version detection
nmap -sV 192.168.56.20

# Aggressive scan with OS detection
nmap -A 192.168.56.20

# Specific port range
nmap -p 1-1000 192.168.56.20
```

## Detection Logic

### SPL Query

```spl
index=sysmon_events EventCode=3
| stats dc(DestinationPort) as unique_ports, count as total_connections by SourceIp
| where unique_ports >= 15
| sort -unique_ports
```

### Advanced Query with Port Categories

```spl
index=sysmon_events EventCode=3
| stats dc(DestinationPort) as unique_ports by SourceIp, DestinationIp
| where unique_ports >= 15
| eval scan_type=case(
    unique_ports >= 100, "Full Port Scan",
    unique_ports >= 50, "Extensive Scan",
    unique_ports >= 15, "Targeted Scan"
  )
| table SourceIp, DestinationIp, unique_ports, scan_type
| sort -unique_ports
```

### Time-Based Detection

```spl
index=sysmon_events EventCode=3 earliest=-5m@m
| bucket _time span=1m
| stats dc(DestinationPort) as ports_per_min by SourceIp, _time
| where ports_per_min >= 10
| eval alert="Port Scan Detected"
| table _time, alert, SourceIp, ports_per_min
```

## Expected Results

### Normal Activity

| Source IP | Unique Ports | Result |
|-----------|--------------|--------|
| 192.168.56.20 | 5 | False positive (legitimate app) |
| 10.0.2.15 | 8 | Normal browsing activity |

### Attack Detected

| Source IP | Unique Ports | Scan Type | Result |
|-----------|--------------|-----------|--------|
| 192.168.56.10 | 150 | Full Port Scan | **ALERT** |
| 192.168.56.10 | 25 | Targeted Scan | **ALERT** |

## Alert Configuration

### Splunk Alert Setup

```spl
# Search
index=sysmon_events EventCode=3 earliest=-5m@m
| stats dc(DestinationPort) as unique_ports by SourceIp
| where unique_ports >= 15

# Trigger Condition
# Number of Results > 0

# Schedule
# Run every 5 minutes
```

### Alert Actions

- **Dashboard Update:** Update Network Activity Dashboard
- **Correlation:** Trigger investigation for follow-up activity
- **Notable Event:** Log for threat hunting

## Investigation Steps

### 1. Validate the Scan

```spl
# Check what ports were targeted
index=sysmon_events EventCode=3 SourceIp="192.168.56.10"
| stats count by DestinationPort
| sort DestinationPort
```

### 2. Identify Target Systems

```spl
# Which systems were scanned?
index=sysmon_events EventCode=3 SourceIp="192.168.56.10"
| stats count by DestinationIp
```

### 3. Check for Follow-up Activity

```spl
# Did the scanner connect to any ports successfully?
index=sysmon_events EventCode=3 SourceIp="192.168.56.10" Initiated=true
| table _time, DestinationIp, DestinationPort, Image
```

### 4. Determine Intent

**Benign Scenarios:**
- Vulnerability scanner (Nessus, Qualys)
- Network monitoring tools
- Legitimate admin activity

**Malicious Indicators:**
- Unknown source IP
- Followed by exploitation attempts
- Occurs outside business hours

## Response Actions

### Immediate

1. **Identify source** - Is it internal or external?
2. **Check authorization** - Is this a scheduled vulnerability scan?
3. **Monitor follow-up** - Watch for exploitation attempts

### Short-term

1. **Network ACL** - Block suspicious source if unauthorized
2. **Service review** - Ensure no unnecessary services exposed
3. **Vulnerability scan** - Run authorized scan to identify exposures

### Long-term

1. **Network segmentation** - Limit lateral movement
2. **Service hardening** - Disable unused services
3. **Baseline establishment** - Define normal scanning patterns

## False Positives

### Common Scenarios

1. **Vulnerability scanners** (Nessus, OpenVAS)
2. **Network monitoring** (Nagios, Zabbix)
3. **Backup software** scanning for agents
4. **Antivirus** network discovery

### Tuning

```spl
# Exclude known scanners
index=sysmon_events EventCode=3
| search NOT SourceIp IN ("192.168.56.100", "10.0.0.50")
| stats dc(DestinationPort) as unique_ports by SourceIp
| where unique_ports >= 15
```

## Testing

### Generate Test Data

```bash
# From Kali - Port scan
nmap -sS -p 1-100 192.168.56.20

# Aggressive scan
nmap -A 192.168.56.20
```

### Verify Detection

```spl
# Check detection triggered
index=sysmon_events EventCode=3 SourceIp="192.168.56.10" earliest=-10m
| stats dc(DestinationPort) as unique_ports
# Should be >= 15
```

## Advanced Variants

### Horizontal Scan Detection (Many hosts, few ports)

```spl
index=sysmon_events EventCode=3
| stats dc(DestinationIp) as unique_hosts by SourceIp, DestinationPort
| where unique_hosts >= 10
| table SourceIp, DestinationPort, unique_hosts
```

### Service-Specific Scanning

```spl
# Detect scanning of specific services
index=sysmon_events EventCode=3
| search DestinationPort IN (22, 23, 445, 3389, 8080)
| stats count by SourceIp, DestinationPort
| where count >= 5
```

## References

- [MITRE ATT&CK T1046](https://attack.mitre.org/techniques/T1046/)
- [Nmap Documentation](https://nmap.org/book/man.html)
- [Sysmon Event ID 3](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon#event-id-3-network-connection-detected)

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2024-01-20 | 1.0 | SOC Team | Initial detection |
| 2024-02-15 | 1.1 | SOC Team | Added time-based detection |
| 2024-03-05 | 1.2 | SOC Team | Added horizontal scan variant |
