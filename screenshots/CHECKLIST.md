# Screenshots Checklist

Use this checklist to capture all necessary screenshots for your GitHub repository documentation.

## 📁 Folder Structure

```
screenshots/
├── architecture-diagram.png
├── dashboard-authentication.png
├── dashboard-threat.png
├── dashboard-endpoint.png
├── dashboard-network.png
├── setup/
│   ├── virtualbox-vms.png
│   ├── kali-desktop.png
│   ├── windows-desktop.png
│   └── network-connectivity.png
├── sysmon/
│   ├── sysmon-service.png
│   ├── sysmon-events.png
│   └── sysmon-config.png
├── splunk/
│   ├── splunk-login.png
│   ├── splunk-home.png
│   ├── splunk-indexes.png
│   └── splunk-forwarder.png
├── attacks/
│   ├── nmap-scan.png
│   ├── nmap-detection.png
│   ├── hydra-attack.png
│   ├── hydra-detection.png
│   ├── powershell-attack.png
│   ├── powershell-detection.png
│   ├── lolbas-attack.png
│   └── lolbas-detection.png
└── alerts/
    ├── alert-brute-force.png
    ├── alert-port-scan.png
    ├── alert-powershell.png
    └── alert-triggered.png
```

---

## 🏗️ Setup Screenshots

### VirtualBox Configuration
- [ ] **virtualbox-vms.png** - Screenshot showing both VMs in VirtualBox
  - Show Kali Linux and Windows 11 VMs
  - Display VM status (running/stopped)
  - Show resource allocation (RAM, CPU)

### Kali Linux
- [ ] **kali-desktop.png** - Kali Linux desktop after installation
  - Show Kali desktop environment
  - Open terminal with `ip addr` command
  - Show network interfaces (eth0, eth1)

### Windows 11
- [ ] **windows-desktop.png** - Windows 11 desktop after installation
  - Show Windows desktop
  - Open PowerShell with `ipconfig` command
  - Show IP addresses

### Network Verification
- [ ] **network-connectivity.png** - Ping tests between all machines
  - Host → Kali ping
  - Host → Windows ping
  - Kali → Windows ping
  - Windows → Kali ping
  - Show all successful pings in one screenshot

---

## 🔧 Sysmon Screenshots

### Service Status
- [ ] **sysmon-service.png** - Sysmon service running
  - Open Services.msc
  - Show "Sysmon64" service with "Running" status
  - Show startup type as "Automatic"

### Event Viewer
- [ ] **sysmon-events.png** - Sysmon events in Event Viewer
  - Open Event Viewer
  - Navigate to Applications and Services Logs → Microsoft → Windows → Sysmon → Operational
  - Show sample events (Event ID 1, 3, 11, 22)
  - Expand one event to show details

### Configuration
- [ ] **sysmon-config.png** - Sysmon configuration loaded
  - Show Sysmon config file (sysmonconfig-export.xml)
  - Or show command: `Sysmon64.exe -c` displaying active config
  - Show schema version and hash

---

## 📊 Splunk Screenshots

### Login Page
- [ ] **splunk-login.png** - Splunk Web login page
  - Show browser with https://localhost:8000
  - Display login form
  - Show Splunk logo

### Home Dashboard
- [ ] **splunk-home.png** - Splunk home page after login
  - Show Splunk home dashboard
  - Display Search & Reporting app
  - Show navigation menu

### Indexes
- [ ] **splunk-indexes.png** - Custom indexes created
  - Navigate to Settings → Indexes
  - Show all custom indexes:
    - windows_events
    - sysmon_events
    - powershell_logs
    - network_logs
  - Show event counts for each index

### Forwarder Status
- [ ] **splunk-forwarder.png** - Universal Forwarder connected
  - Search: `index=_internal source=*metrics.log group=tcpin_connections`
  - Show connection from Windows VM (192.168.56.20)
  - Display hostname and IP

---

## ⚔️ Attack Simulation Screenshots

### Nmap Port Scan

#### Attack
- [ ] **nmap-scan.png** - Nmap scan execution on Kali
  - Open Kali terminal
  - Run: `nmap -sS -sV 192.168.56.20`
  - Show scan output with open ports
  - Show target IP and results

#### Detection
- [ ] **nmap-detection.png** - Port scan detected in Splunk
  - Open Splunk Search & Reporting
  - Run port scan detection query:
    ```spl
    index=sysmon_events EventCode=3 SourceIp="192.168.56.10"
    | stats dc(DestinationPort) as unique_ports by SourceIp
    | where unique_ports >= 15
    ```
  - Show results table with SourceIp and unique_ports count

### Brute Force Attack

#### Attack
- [ ] **hydra-attack.png** - Hydra brute force on Kali
  - Open Kali terminal
  - Run: `hydra -l victim -P passwords.txt rdp://192.168.56.20`
  - Show Hydra attempting passwords
  - Show successful password found (if applicable)

#### Detection
- [ ] **hydra-detection.png** - Brute force detected in Splunk
  - Open Splunk Authentication Dashboard
  - Show spike in failed logins
  - Run detection query:
    ```spl
    index=windows_events EventCode=4625
    | stats count by IpAddress, TargetUserName
    | where count >= 5
    ```
  - Show results with 192.168.56.10 and high count

### PowerShell Attack

#### Attack
- [ ] **powershell-attack.png** - PowerShell encoded command execution
  - Open Windows PowerShell
  - Run encoded command:
    ```powershell
    $cmd = "Get-Process"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    powershell.exe -EncodedCommand $encoded
    ```
  - Show command execution
  - Show output

#### Detection
- [ ] **powershell-detection.png** - PowerShell attack detected in Splunk
  - Open Splunk Threat Dashboard
  - Run PowerShell detection query:
    ```spl
    index=sysmon_events EventCode=1 CommandLine="*-enc*"
    | table _time, CommandLine, User
    ```
  - Show decoded command in results
  - Show alert triggered

### LOLBAS Techniques

#### Attack
- [ ] **lolbas-attack.png** - LOLBAS execution (certutil)
  - Open Command Prompt
  - Run: `certutil.exe -urlcache -split -f http://example.com/test.txt test.txt`
  - Show command execution
  - Show file downloaded

#### Detection
- [ ] **lolbas-detection.png** - LOLBAS detected in Splunk
  - Open Splunk Threat Dashboard
  - Run LOLBAS detection query:
    ```spl
    index=sysmon_events EventCode=1 Image="*certutil*" CommandLine="*urlcache*"
    | table _time, CommandLine, User
    ```
  - Show certutil.exe in results
  - Show technique name

---

## 📊 Dashboard Screenshots

### Authentication Dashboard
- [ ] **dashboard-authentication.png** - Full authentication dashboard view
  - Show all 6 panels:
    1. Failed logins over time (line chart)
    2. Successful logins over time (line chart)
    3. Top failed login users (pie chart)
    4. Login failures by source IP (bar chart)
    5. Brute force detection (stacked bar)
    6. Account lockouts (table)
  - Show real-time data from attacks
  - Ensure dashboard is fully visible

### Threat Detection Dashboard
- [ ] **dashboard-threat.png** - Full threat detection dashboard view
  - Show all 6 panels:
    1. Suspicious process creation (area chart)
    2. Encoded PowerShell commands (table)
    3. LOLBAS detection (table)
    4. Process injection attempts (table)
    5. Scheduled tasks created (table)
    6. Threat summary (single value)
  - Show data from attack simulations

### Endpoint Activity Dashboard
- [ ] **dashboard-endpoint.png** - Full endpoint activity dashboard view
  - Show all 6 panels:
    1. Process creation over time (line chart)
    2. Top processes created (pie chart)
    3. File creation events (table)
    4. Registry modifications (table)
    5. DNS queries (bar chart)
    6. DLLs loaded (bar chart)
  - Show normal and suspicious activity

### Network Activity Dashboard
- [ ] **dashboard-network.png** - Full network activity dashboard view
  - Show all 6 panels:
    1. Network connections over time (line chart)
    2. Top destination IPs (table)
    3. Port scan detection (bar chart)
    4. Outbound connections by process (table)
    5. Connections to unusual ports (table)
    6. Protocol distribution (pie chart)
  - Show network traffic patterns

---

## 🚨 Alert Screenshots

### Alert Configuration
- [ ] **alert-brute-force.png** - Brute force alert configuration
  - Show alert creation screen
  - Display alert name: "ALERT - Brute Force Login Attempt"
  - Show SPL query
  - Show trigger condition (5+ failed logins)
  - Show schedule (every 5 minutes)

- [ ] **alert-port-scan.png** - Port scan alert configuration
  - Show alert creation screen
  - Display alert name: "ALERT - Network Port Scan Detected"
  - Show SPL query
  - Show trigger condition (15+ unique ports)

- [ ] **alert-powershell.png** - PowerShell alert configuration
  - Show alert creation screen
  - Display alert name: "ALERT - Suspicious PowerShell Execution"
  - Show SPL query
  - Show trigger condition

### Triggered Alerts
- [ ] **alert-triggered.png** - List of triggered alerts
  - Navigate to Search & Reporting → Alerts
  - Show "Triggered Alerts" view
  - Display list of triggered alerts with timestamps
  - Show alert severity and details
  - Show which attacks triggered which alerts

---

## 🏗️ Architecture Diagrams

### Main Architecture
- [ ] **architecture-diagram.png** - Complete lab architecture
  - Show all components:
    - Host (Windows 11)
    - Kali Linux VM (192.168.56.10)
    - Windows 11 VM (192.168.56.20)
    - Splunk Enterprise
  - Show network connections:
    - Host-Only network (192.168.56.0/24)
    - NAT network (10.0.2.0/24)
  - Show data flow:
    - Attacks → Victim → Sysmon → Forwarder → Splunk
  - Use clear labels and arrows

### Data Flow Diagram (Optional)
- [ ] **data-flow-diagram.png** - Log collection data flow
  - Show event generation (Sysmon)
  - Show log forwarding (Universal Forwarder)
  - Show log indexing (Splunk)
  - Show detection and alerting
  - Show dashboard visualization

---

## 📝 Screenshot Tips

### Quality
- **Resolution:** Minimum 1920x1080
- **Format:** PNG (lossless)
- **Compression:** None or minimal
- **Clarity:** Ensure text is readable

### Composition
- **Full Screen:** Capture entire application window
- **Context:** Include relevant UI elements (menus, toolbars)
- **Focus:** Highlight important areas with boxes/arrows (optional)
- **Consistency:** Use same theme/colors across screenshots

### Tools
- **Windows:** Snipping Tool, Snip & Sketch, or Win+Shift+S
- **macOS:** Cmd+Shift+4
- **Linux:** GNOME Screenshot, Shutter, or Flameshot
- **Advanced:** ShareX, Greenshot, Lightshot

### Best Practices
1. **Clean Environment:** Close unnecessary tabs/applications
2. **Consistent Theme:** Use dark mode consistently (or light mode)
3. **Realistic Data:** Show actual attack data, not test data
4. **Annotations:** Add arrows/boxes to highlight important areas
5. **File Naming:** Use descriptive names (e.g., `nmap-detection.png`)
6. **Organization:** Group by category in folders

---

## ✅ Final Checklist

Before publishing to GitHub, verify:

- [ ] All 20+ screenshots captured
- [ ] Screenshots organized in correct folders
- [ ] Images are clear and readable
- [ ] File names are descriptive
- [ ] README.md references correct image paths
- [ ] No sensitive information visible (passwords, personal data)
- [ ] Consistent styling across all screenshots
- [ ] Architecture diagrams are accurate
- [ ] Dashboard screenshots show real data from attacks

---

## 📤 Uploading to GitHub

### Method 1: Direct Upload
1. Navigate to your GitHub repository
2. Click "Add file" → "Upload files"
3. Drag and drop screenshots folder
4. Commit with message: "Add screenshots for documentation"

### Method 2: Git Commands
```bash
# Navigate to repository
cd "R:\Home SOC"

# Add screenshots
git add screenshots/

# Commit
git commit -m "Add comprehensive screenshots for SOC lab documentation"

# Push
git push origin main
```

### Method 3: Git LFS (Large File Storage)
If screenshots exceed GitHub size limits:

```bash
# Install Git LFS
git lfs install

# Track PNG files
git lfs track "*.png"

# Add and commit
git add .gitattributes
git add screenshots/
git commit -m "Add screenshots with Git LFS"
git push origin main
```

---

**Total Screenshots Required:** 20-25 images  
**Estimated Total Size:** 10-20 MB  
**Time to Capture:** 30-60 minutes

**Last Updated:** January 2024
