# Dashboard Documentation

## Overview

The Home SOC Lab includes four interactive dashboards for real-time security monitoring and threat detection.

## Dashboard 1: Authentication Monitor

![Authentication Dashboard](../screenshots/dashboard-authentication.png)

### Purpose
Monitor all authentication activity, detect brute force attacks, and identify account compromise.

### Panels

#### 1. Failed Logins Over Time
**Visualization:** Line Chart
```spl
index=windows_events EventCode=4625
| timechart count by TargetUserName span=5m
```

#### 2. Successful Logins Over Time
**Visualization:** Line Chart
```spl
index=windows_events EventCode=4624 Logon_Type!=3
| timechart count by Logon_Type span=5m
```

#### 3. Top Failed Login Users
**Visualization:** Pie Chart
```spl
index=windows_events EventCode=4625
| top limit=10 TargetUserName
```

#### 4. Login Failures by Source IP
**Visualization:** Bar Chart
```spl
index=windows_events EventCode=4625
| stats count by IpAddress
| sort -count
| head 10
```

#### 5. Brute Force Detection
**Visualization:** Stacked Bar Chart
```spl
index=windows_events (EventCode=4625 OR EventCode=4624)
| eval status=if(EventCode=4625,"Failed","Success")
| stats count by status, TargetUserName
| sort -count
```

#### 6. Account Lockouts
**Visualization:** Statistics Table
```spl
index=windows_events EventCode=4740
| table _time, TargetUserName, Caller_Computer_Name
```

### Use Cases
- Detect credential stuffing attacks
- Identify compromised accounts
- Monitor privileged account usage
- Track after-hours authentication

---

## Dashboard 2: Threat Detection

![Threat Dashboard](../screenshots/dashboard-threat.png)

### Purpose
Detect advanced threats including LOLBAS abuse, process injection, and malware execution.

### Panels

#### 1. Suspicious Process Creation
**Visualization:** Area Chart
```spl
index=sysmon_events EventCode=1
| search (Image="*powershell*" OR Image="*cmd*" OR Image="*certutil*" OR Image="*mshta*" OR Image="*wmic*")
| timechart count by Image span=5m
```

#### 2. Encoded PowerShell Commands
**Visualization:** Statistics Table
```spl
index=sysmon_events EventCode=1 CommandLine="*-enc*" OR CommandLine="*-EncodedCommand*"
| table _time, CommandLine, User, ParentImage
```

#### 3. LOLBAS Detection
**Visualization:** Statistics Table
```spl
index=sysmon_events EventCode=1
| search (Image="*certutil*" AND CommandLine="*urlcache*")
  OR (Image="*bitsadmin*")
  OR (Image="*mshta*")
| stats count by Image, CommandLine
```

#### 4. Process Injection Attempts
**Visualization:** Statistics Table
```spl
index=sysmon_events (EventCode=8 OR EventCode=10 OR EventCode=25)
| stats count by SourceImage, TargetImage, User
| sort -count
```

#### 5. Scheduled Tasks Created
**Visualization:** Statistics Table
```spl
index=sysmon_events EventCode=1
| search (Image="*schtasks*" AND CommandLine="*/create*")
| table _time, CommandLine, User
```

#### 6. Threat Summary
**Visualization:** Single Value
```spl
index=sysmon_events (EventCode=1 OR EventCode=3 OR EventCode=8 OR EventCode=10)
| stats count as "Total Events"
```

### Use Cases
- Detect living-off-the-land techniques
- Identify process injection attacks
- Monitor persistence mechanisms
- Track malware execution

---

## Dashboard 3: Endpoint Activity

![Endpoint Dashboard](../screenshots/dashboard-endpoint.png)

### Purpose
Monitor endpoint behavior including process creation, file modifications, and registry changes.

### Panels

#### 1. Process Creation Over Time
**Visualization:** Line Chart
```spl
index=sysmon_events EventCode=1
| timechart count span=5m
```

#### 2. Top Processes Created
**Visualization:** Pie Chart
```spl
index=sysmon_events EventCode=1
| rex field=Image "(?<ProcessName>[^\\\\]+)$"
| top limit=15 ProcessName
```

#### 3. File Creation Events
**Visualization:** Statistics Table
```spl
index=sysmon_events EventCode=11
| table _time, Image, TargetFilename, User
| head 50
```

#### 4. Registry Modifications
**Visualization:** Statistics Table
```spl
index=sysmon_events (EventCode=12 OR EventCode=13 OR EventCode=14)
| stats count by EventType, TargetObject, Image
| sort -count
| head 20
```

#### 5. DNS Queries
**Visualization:** Bar Chart
```spl
index=sysmon_events EventCode=22
| top limit=20 QueryName
```

#### 6. DLLs Loaded
**Visualization:** Bar Chart
```spl
index=sysmon_events EventCode=7
| top limit=20 ImageLoaded
```

### Use Cases
- Track system modifications
- Identify suspicious file creation
- Monitor registry persistence
- Detect DLL hijacking

---

## Dashboard 4: Network Activity

![Network Dashboard](../screenshots/dashboard-network.png)

### Purpose
Monitor network connections, detect port scans, and identify suspicious outbound traffic.

### Panels

#### 1. Network Connections Over Time
**Visualization:** Line Chart
```spl
index=sysmon_events EventCode=3
| timechart count span=5m
```

#### 2. Top Destination IPs
**Visualization:** Statistics Table
```spl
index=sysmon_events EventCode=3
| top limit=20 DestinationIp, DestinationPort
```

#### 3. Port Scan Detection
**Visualization:** Bar Chart
```spl
index=sysmon_events EventCode=3
| stats dc(DestinationPort) as UniquePorts, count by SourceIp
| where UniquePorts > 10
| sort -UniquePorts
```

#### 4. Outbound Connections by Process
**Visualization:** Statistics Table
```spl
index=sysmon_events EventCode=3
| rex field=Image "(?<ProcessName>[^\\\\]+)$"
| stats count by ProcessName, DestinationIp, DestinationPort
| sort -count
| head 20
```

#### 5. Connections to Unusual Ports
**Visualization:** Statistics Table
```spl
index=sysmon_events EventCode=3
| search NOT (DestinationPort=80 OR DestinationPort=443 OR DestinationPort=53 OR DestinationPort=445)
| stats count by DestinationPort, DestinationIp, SourceIp
| sort -count
| head 20
```

#### 6. Protocol Distribution
**Visualization:** Pie Chart
```spl
index=sysmon_events EventCode=3
| top Protocol
```

### Use Cases
- Detect network reconnaissance
- Identify C2 communication
- Monitor data exfiltration
- Track lateral movement

---

## Dashboard Creation Guide

### Step 1: Create New Dashboard

1. Navigate to **Search & Reporting** app
2. Click **Dashboards** → **Create New Dashboard**
3. Select **Classic Dashboard**
4. Enter dashboard title
5. Click **Create**

### Step 2: Add Panels

1. Click **Add Panel**
2. Select **New** → Choose visualization type
3. Enter SPL query
4. Configure time range (default: Last 24 hours)
5. Click **Add to Dashboard**

### Step 3: Customize Layout

1. Click **Edit** → **Edit Panels**
2. Drag panels to arrange layout
3. Resize panels as needed
4. Click **Done**

### Step 4: Set Auto-Refresh

1. Click **Edit** → **Edit Dashboard Settings**
2. Set **Refresh** to 30 seconds or 1 minute
3. Click **Save**

---

## Dashboard Best Practices

### Performance Optimization

1. **Use time ranges wisely** - Limit to last 24 hours for real-time dashboards
2. **Schedule searches** - Use saved searches for complex queries
3. **Limit results** - Use `head` or `top` to reduce data volume
4. **Index filtering** - Always specify `index=` in searches

### Visual Design

1. **Consistent colors** - Use same color scheme across dashboards
2. **Clear labels** - Ensure all panels have descriptive titles
3. **Logical grouping** - Group related panels together
4. **White space** - Don't overcrowd dashboards

### Alerting Integration

1. **Drill-down searches** - Link panels to detailed investigations
2. **Alert triggers** - Configure alerts for critical thresholds
3. **Email subscriptions** - Schedule dashboard PDF delivery
4. **Notable events** - Integrate with Enterprise Security

---

## Sample Queries for Common Scenarios

### Hunt for Lateral Movement

```spl
index=sysmon_events EventCode=3
| search DestinationPort IN (445, 135, 3389, 5985, 5986)
| stats count by SourceIp, DestinationIp, DestinationPort
| where count >= 5
```

### Detect Data Exfiltration

```spl
index=sysmon_events EventCode=3 Initiated=true
| search NOT (DestinationPort=80 OR DestinationPort=443)
| stats sum(TotalBytes) as bytes by SourceIp, DestinationIp
| where bytes > 10485760  // >10 MB
```

### Identify Persistence

```spl
index=sysmon_events (EventCode=12 OR EventCode=13)
| search TargetObject="*\\Run\\*" OR TargetObject="*\\RunOnce\\*"
| table _time, Image, TargetObject, Details
```

### Monitor Scheduled Tasks

```spl
index=sysmon_events EventCode=1
| search Image="*schtasks*" CommandLine="*/create*"
| table _time, User, CommandLine
```

---

## Dashboard Maintenance

### Regular Reviews

- **Weekly:** Review dashboard usage and performance
- **Monthly:** Update queries based on new threats
- **Quarterly:** Redesign dashboards based on feedback

### Version Control

- Export dashboard XML to Git repository
- Document all query changes
- Track dashboard evolution

### User Training

- Train SOC analysts on dashboard interpretation
- Create runbooks for common scenarios
- Document investigation workflows

---

## Troubleshooting

### Dashboard Not Loading

**Issue:** Dashboard shows "Search is waiting for input"

**Solution:** Check time range picker and ensure inputs have default values

### No Results Showing

**Issue:** Panels display "No results found"

**Solution:**
1. Verify data is being indexed
2. Check time range
3. Validate SPL syntax
4. Ensure correct index/sourcetype

### Slow Performance

**Issue:** Dashboard takes too long to load

**Solution:**
1. Reduce time range
2. Optimize queries
3. Use summary indexing
4. Schedule searches

---

## References

- [Splunk Dashboard Examples](https://docs.splunk.com/Documentation/Splunk/latest/DashEval/Intro)
- [Splunk Visualization Reference](https://docs.splunk.com/Documentation/Splunk/latest/DashStudio/vizRef)
- [Dashboard Best Practices](https://www.splunk.com/en_us/blog/best-practices/dashboard-design.html)
