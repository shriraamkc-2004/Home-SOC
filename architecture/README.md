# Architecture Documentation

## System Architecture

### Overview

The Home SOC Lab implements a three-tier architecture:
1. **Attack Layer** - Kali Linux VM for red team simulation
2. **Target Layer** - Windows 11 VM as the victim endpoint
3. **Analysis Layer** - Splunk Enterprise on host for blue team operations

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HOST MACHINE (Windows 11)                     │
│                         192.168.56.1 / NAT DHCP                      │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    VirtualBox Hypervisor                        │ │
│  │                                                                 │ │
│  │  ┌─────────────────────┐         ┌──────────────────────┐     │ │
│  │  │   ATTACK VM         │         │   VICTIM VM          │     │ │
│  │  │   Kali Linux        │         │   Windows 11         │     │ │
│  │  │   192.168.56.10     │         │   192.168.56.20      │     │ │
│  │  │                     │         │                      │     │ │
│  │  │  • Nmap             │         │  • Sysmon            │     │ │
│  │  │  • Hydra            │         │  • Splunk UF         │     │ │
│  │  │  • Metasploit       │         │  • Windows Defender  │     │ │
│  │  │  • Burp Suite       │         │  • PowerShell 7      │     │ │
│  │  │  • John the Ripper  │         │                      │     │ │
│  │  └──────────┬──────────┘         └──────────┬───────────┘     │ │
│  │             │                               │                  │ │
│  │             │    Host-Only Network          │                  │ │
│  │             │    192.168.56.0/24            │                  │ │
│  │             └───────────────────────────────┘                  │ │
│  │                                                                 │ │
│  │  ┌──────────────────────────────────────────────────────────┐  │ │
│  │  │              SIEM SERVER (Splunk Enterprise)              │  │ │
│  │  │                  Port 8000 (Web UI)                       │  │ │
│  │  │                  Port 9997 (Data Receiving)               │  │ │
│  │  │                                                           │  │ │
│  │  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │  │ │
│  │  │  │  Indexes    │  │  Dashboards  │  │  Alerts        │  │  │ │
│  │  │  │             │  │              │  │                │  │  │ │
│  │  │  │ • windows   │  │ • Auth       │  │ • Brute Force │  │  │ │
│  │  │  │ • sysmon    │  │ • Threat     │  │ • Port Scan   │  │  │ │
│  │  │  │ • powershell│  │ • Endpoint   │  │ • PowerShell  │  │  │ │
│  │  │  │ • network   │  │ • Network    │  │ • LOLBAS      │  │  │ │
│  │  │  └─────────────┘  └──────────────┘  └────────────────┘  │  │ │
│  │  └──────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Network Architecture

### Network Segmentation

| Network | CIDR | Purpose | Access |
|---------|------|---------|--------|
| Host-Only | 192.168.56.0/24 | VM-to-VM communication | Internal only |
| NAT | 10.0.2.0/24 | Internet access for VMs | Outbound only |
| Host Loopback | 127.0.0.1 | Splunk Web UI | Host only |

### IP Addressing Scheme

| Component | Host-Only IP | NAT IP | Role |
|-----------|--------------|--------|------|
| Host OS | 192.168.56.1 | DHCP | Splunk Server |
| Kali VM | 192.168.56.10 | DHCP | Attacker |
| Windows VM | 192.168.56.20 | DHCP | Victim |
| Splunk Web | - | - | localhost:8000 |
| Splunk Forwarding | - | - | 192.168.56.1:9997 |

### Firewall Rules

**Host-Only Network (192.168.56.0/24):**
- Allow all ICMP (ping)
- Allow TCP 3389 (RDP) to Windows VM
- Allow TCP 445 (SMB) to Windows VM
- Allow TCP 22 (SSH) to Kali VM
- Allow TCP 9997 (Splunk forwarding) to Host

**NAT Network (10.0.2.0/24):**
- Allow outbound HTTP/HTTPS (80, 443)
- Allow outbound DNS (53)
- Block inbound from external

## Data Flow Architecture

### Log Collection Pipeline

```
┌─────────────────┐
│  Windows VM     │
│  (Victim)       │
└────────┬────────┘
         │
         │ Events generated
         ▼
┌─────────────────┐
│  Sysmon         │
│  (Event IDs)    │
│                 │
│  • 1: Process   │
│  • 3: Network   │
│  • 11: File     │
│  • 22: DNS      │
└────────┬────────┘
         │
         │ Windows Event Log
         ▼
┌─────────────────┐
│  Splunk UF      │
│  (Forwarder)    │
│                 │
│  Inputs:        │
│  • Security Log │
│  • Sysmon Log   │
│  • PowerShell   │
└────────┬────────┘
         │
         │ TCP 9997
         │ (Encrypted)
         ▼
┌─────────────────┐
│  Splunk Indexer │
│  (Host)         │
│                 │
│  Parsing:       │
│  • Field extrac │
│  • Timestamp    │
│  • Sourcetype   │
└────────┬────────┘
         │
         │ Index routing
         ▼
┌─────────────────┐
│  Indexes        │
│                 │
│  • windows_event│
│  • sysmon_event │
│  • powershell   │
│  • network_logs │
└────────┬────────┘
         │
         │ Search & Reporting
         ▼
┌─────────────────┐
│  Dashboards     │
│  & Alerts       │
└─────────────────┘
```

### Event Flow Example: Brute Force Attack

```
1. Kali runs Hydra → Attempts RDP login to 192.168.56.20:3389
   ↓
2. Windows Security Log → EventCode 4625 (Failed Logon)
   ↓
3. Splunk UF detects event → Forwards to 192.168.56.1:9997
   ↓
4. Splunk Indexer receives → Parses and indexes
   ↓
5. Alert triggers → "Multiple Failed Logins from 192.168.56.10"
   ↓
6. Dashboard updates → Authentication Dashboard shows spike
   ↓
7. SOC Analyst investigates → Runs correlation searches
   ↓
8. Incident Response → Containment, Eradication, Recovery
```

## Component Specifications

### Kali Linux (Attacker)

**Purpose:** Red team operations and attack simulation

**Tools Installed:**
- Nmap - Network scanning and reconnaissance
- Hydra - Brute force attacks
- Metasploit - Exploitation framework
- Burp Suite - Web application testing
- John the Ripper - Password cracking
- Wireshark - Packet analysis
- Netcat - Reverse shells and file transfer

**Resource Allocation:**
- RAM: 3 GB
- CPU: 2 cores
- Storage: 30 GB
- Network: Host-Only + NAT

### Windows 11 (Victim)

**Purpose:** Target system for attack simulation

**Security Tools:**
- Sysmon 15.x - Advanced event logging
- Splunk Universal Forwarder - Log forwarding
- Windows Defender - Endpoint protection (disabled for lab)
- PowerShell 7 - Script execution and logging

**Monitoring Configuration:**
- Process Creation (Event ID 1)
- Network Connections (Event ID 3)
- File Creation (Event ID 11)
- Registry Changes (Event ID 12, 13, 14)
- DNS Queries (Event ID 22)
- PowerShell Script Block (Event ID 4104)

**Resource Allocation:**
- RAM: 4 GB
- CPU: 2 cores
- Storage: 50 GB
- Network: Host-Only + NAT

### Splunk Enterprise (SIEM)

**Purpose:** Centralized log management and analysis

**Configuration:**
- Receiving Port: 9997
- Web Interface: 8000
- Indexes: 4 custom indexes
- Add-ons: Windows TA, Sysmon TA
- Data Retention: 30 days (lab setting)

**Resource Requirements:**
- RAM: 8 GB minimum (shared with host)
- CPU: 4 cores recommended
- Storage: 20 GB for indexes
- License: Free (500 MB/day indexing)

## Security Considerations

### Lab Isolation

- Host-Only network prevents external exposure
- NAT network provides controlled internet access
- No production systems or sensitive data in lab
- All attacks contained within virtual environment

### Best Practices

1. **Snapshot VMs** before major changes
2. **Document all changes** for reproducibility
3. **Regular backups** of Splunk indexes
4. **Version control** for detection rules
5. **Test detections** with known-good attacks

### Production Differences

| Aspect | Lab Environment | Production SOC |
|--------|----------------|----------------|
| Scale | 1-2 endpoints | 1000+ endpoints |
| Data Volume | < 500 MB/day | GBs to TBs/day |
| Users | 1 analyst | 10+ analysts |
| Retention | 30 days | 1-7 years |
| HA/DR | None | Clustered |
| Integration | Manual | Automated |

## Scalability Considerations

### Vertical Scaling
- Increase Splunk RAM/CPU allocation
- Expand storage for longer retention
- Upgrade to Splunk Enterprise license

### Horizontal Scaling
- Add more victim VMs (different OS versions)
- Deploy additional forwarders
- Implement distributed Splunk architecture
- Add search head clustering

### Future Additions
- Active Directory Domain Controller
- Linux endpoints (Ubuntu/CentOS)
- Cloud integration (AWS/Azure logs)
- Container environments (Docker/Kubernetes)
- IoT/OT devices

## Diagrams

### Physical Deployment

```
┌─────────────────────────────────────┐
│      Laptop / Workstation           │
│      (Windows 11 Host)              │
│                                     │
│  ┌───────────────────────────────┐ │
│  │    VirtualBox 7.x             │ │
│  │                               │ │
│  │  ┌─────────┐  ┌───────────┐  │ │
│  │  │  Kali   │  │ Windows   │  │ │
│  │  │  VM     │  │ VM        │  │ │
│  │  └─────────┘  └───────────┘  │ │
│  │                               │ │
│  │  ┌─────────────────────────┐  │ │
│  │  │  Splunk Enterprise      │  │ │
│  │  └─────────────────────────┘  │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Logical Flow

```
Attack → Victim → Logs → SIEM → Detection → Alert → Response
  │         │        │       │        │         │        │
  │         │        │       │        │         │        │
Kali     Windows   Sysmon  Splunk   Rules    Email    IR Plan
         Defender  UF      Indexer  Dash     Ticket   Playbook
```

## Conclusion

This architecture provides a realistic SOC environment while maintaining isolation and safety. The modular design allows for easy expansion and customization based on specific learning objectives or threat scenarios.

For implementation details, see the [Installation Guide](../docs/INSTALLATION.md).
