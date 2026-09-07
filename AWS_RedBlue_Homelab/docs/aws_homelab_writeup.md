# Project Showcases: AWS Red Team vs. Blue Team Cybersecurity Homelab

This repository documents the architecture, deployment, and testing of a cloud-based Red Team vs. Blue Team emulation environment hosted on AWS. The lab serves as a hands-on playground to simulate real-world cyberattacks, capture network traffic, aggregate security event logs, and analyze system vulnerabilities.

---

## 1. Executive Summary

### Objective
To design and deploy a secure, isolated cloud infrastructure simulating a corporate network, allowing for simultaneous offensive testing (Red Team) and security monitoring/vulnerability management (Blue Team).

### Outcome
*   **Infrastructure:** Built a custom AWS VPC containing Kali Linux (Attacker), Windows Server 2022 (Target), and Ubuntu 22.04 LTS (Security Tools SIEM), deployed as Infrastructure as Code using Terraform.
*   **Offensive Operations:** Executed network reconnaissance, SMB enumeration, and RDP brute-force simulation using `Nmap` and `Metasploit`.
*   **Defensive Operations:** Deployed a central **Splunk Enterprise** instance to ingest Windows Security Event Logs via **Splunk Universal Forwarder**, configured **Tenable Nessus** for vulnerability scanning, and performed network packet captures using `tcpdump` for offline analysis in Wireshark.
*   **Remediation:** Identified critical security gaps (unsecured RDP, active SMB shares, disabled firewalls) and documented mitigation procedures to harden the target Windows machine.

---

## 2. Infrastructure Architecture & Network Topology

The lab is hosted in an isolated AWS Virtual Private Cloud (VPC) to ensure that attack traffic remains contained.

```mermaid
graph TD
    subgraph AWS VPC (10.0.0.0/16)
        IGW[Internet Gateway] <--> PublicSubnet[Public Subnet 10.0.1.0/24]

        subgraph Public Subnet
            Kali[Kali Linux Attacker<br>10.0.1.10]
            WinTarget[Windows Server 2022 Target<br>10.0.1.20]
            BlueSIEM[Ubuntu 22.04 LTS SIEM<br>10.0.1.30]
        end
    end

    CW[CloudWatch<br>VPC Flow Logs]
    CT[S3 Bucket<br>CloudTrail]

    User[My Local Workstation] <-->|SSH / Port 22| Kali
    User <-->|RDP / Port 3389| WinTarget
    User <-->|Splunk Web / Port 8000| BlueSIEM
    User <-->|Nessus / Port 8834| BlueSIEM

    WinTarget -->|Splunk Forwarder / Port 9997| BlueSIEM
    Kali -.->|Active Attacks: Nmap / Metasploit| WinTarget

    PublicSubnet -->|All network flows| CW
    IGW -->|All AWS API calls| CT
```

### Resource Configuration Table

| Instance Role | Operating System | AWS Instance Type | Key Tools Installed | Security Group Configuration |
| :--- | :--- | :--- | :--- | :--- |
| **Attacker (Red Team)** | Kali Linux | `t3.medium` | `Nmap`, `Metasploit`, `Hydra`, `John the Ripper` | Inbound: SSH (22), RDP (3389) from Admin IP |
| **Target (Victim)** | Windows Server 2022 | `t3.small` | Splunk Universal Forwarder | Inbound: RDP (3389) from Admin IP, All traffic from Subnet |
| **SIEM & Scanner (Blue Team)** | Ubuntu 22.04 LTS | `t3.large` | Splunk Enterprise, Tenable Nessus, `tcpdump` | Inbound: Splunk Web (8000), Splunk Lsnr (9997), Nessus (8834) |

---

## 3. Implementation Workflow

### Phase 1: Cloud & Network Setup
1.  **VPC & Subnet Creation:** Configured a custom VPC `RedBlue-Lab-VPC` (`10.0.0.0/16`) and mapped a public subnet `10.0.1.0/24` with an attached Internet Gateway for external management.
2.  **Security Group Partitioning:**
    *   **Main Security Group:** Restricted management access (SSH/RDP) to the author's public IP address while allowing unrestricted internal subnet traffic for testing.
    *   **Security Tools Group:** Permitted inbound connections to Splunk Web (8000), Nessus Web (8834), and Splunk indexer port (9997).
3.  **EC2 Deployment:** Deployed all three instances using Terraform, codifying the entire infrastructure as repeatable, version-controlled configuration. See `terraform/` for the complete IaC source.

---

### Phase 2: Blue Team Tooling & Logging Pipeline

```mermaid
flowchart LR
    Win[Windows Security Logs] -->|Splunk Universal Forwarder| Port9997[Splunk Receiver: Port 9997]
    Port9997 -->|Index: win-security| Splunk[Splunk Indexer & Search Head]
```

1.  **Splunk Enterprise Setup:** Installed Splunk on the Ubuntu Security box, configured it to start on boot, and created a receiving port on `9997` targeting a custom index: `win-security`.
2.  **Splunk Universal Forwarder Deployment:** Installed the forwarder on the Windows target.
3.  **Log Forwarding Configuration:** Configured `C:\Program Files\SplunkUniversalForwarder\etc\system\local\inputs.conf` on the Windows target to ship Windows Event Logs:
    ```ini
    [WinEventLog://Security]
    index = win-security
    disabled = 0
    
    [WinEventLog://Application]
    index = win-security
    disabled = 0
    
    [WinEventLog://System]
    index = win-security
    disabled = 0
    ```
4.  **Vulnerability Management:** Deployed Tenable Nessus Essentials on the Ubuntu box to perform scheduled credentials-free asset scans.

---

## 4. Attack Simulation & Incident Analysis

### Attack 1: Active Reconnaissance & Port Scanning
**Action:** Performed an active service scan from the Kali Linux box targeting the Windows Server.
```bash
nmap -sV -sC -p- 10.0.1.20 -oN windows_scan.txt
```
**Results:**
*   Identified Port `135` (MSRPC), Port `139/445` (NetBIOS/SMB), and Port `3389` (RDP) as open.
*   OS footprinted as Windows Server 2022.

---

### Attack 2: SMB Enumeration & RDP Service Discovery
**Action:** Launched Metasploit auxiliary modules to enumerate the SMB version and confirm RDP service availability on the Windows target, mapping the attack surface before credential attacks.
```msf
use auxiliary/scanner/smb/smb_version
set RHOSTS 10.0.1.20
run

use auxiliary/scanner/rdp/rdp_scanner
set RHOSTS 10.0.1.20
run
```
**Results:** Confirmed SMB v2/v3 active with signing disabled (relay-attack surface) and RDP service open with no Network Level Authentication enforced. Proceeded to brute-force simulation using Hydra against the exposed RDP service:
```bash
hydra -l Administrator -P /usr/share/wordlists/rockyou.txt rdp://10.0.1.20 -t 4 -W 3
```

---

### Blue Team Analysis: Splunk Event Corroboration
Using the Splunk Search Processing Language (SPL), simulated brute-force attempts were correlated using standard Windows Security Event IDs:

```
index=win-security EventCode=4625
| stats count by TargetUserName, IpAddress, _time
| sort - count
```

#### Key Event Codes Monitored:
*   **Event ID 4625:** An account failed to log on (indicating brute-force attempts).
*   **Event ID 4624:** An account was successfully logged on.
*   **Event ID 4740:** A user account was locked out due to excessive logon failures.

```text
+-------------------+--------------+---------+----------------------------+
| TargetUserName    | Source IP    | EventID | Description                |
+-------------------+--------------+---------+----------------------------+
| Administrator     | 10.0.1.10    | 4625    | Failed logon attempt       |
| Administrator     | 10.0.1.10    | 4625    | Failed logon attempt       |
| Administrator     | 10.0.1.10    | 4740    | Account Locked Out         |
+-------------------+--------------+---------+----------------------------+
```

---

### Attack 3: Vulnerability Assessment & Traffic Analysis
1.  **Nessus Vulnerability Scan:** Run a "Basic Network Scan" from the Nessus interface against `10.0.1.20`. 
2.  **Traffic Capture:** While scanning, executed a `tcpdump` capture on the Ubuntu monitoring box interface to record the active scan traffic:
    ```bash
    sudo tcpdump -i ens5 host 10.0.1.20 -w /tmp/nessus_scan.pcap
    ```
3.  **Wireshark Post-Mortem:** Analyzed `nessus_scan.pcap` in Wireshark. Observed massive bursts of SYN packets on randomized ports, HTTP request payloads targeting common web directories, and credentials probe sequences on RDP/SMB.

---

## 5. Hardening & Remediation Recommendations

Based on findings from the attack simulation and Nessus scans, the following hardening steps are recommended for the Windows target:

1.  **Enforce Host Firewall Policy:**
    *   **Finding:** Windows Defender Firewall was disabled to allow logs transmission.
    *   **Mitigation:** Enable Windows Defender Firewall. Configure explicit inbound rules to allow port `9997` outgoing traffic to the Splunk receiver only, rather than disabling the entire firewall.
2.  **RDP Hardening:**
    *   **Finding:** RDP (3389) was open and susceptible to password-guessing/brute-force attacks.
    *   **Mitigation:** Limit RDP access via Security Groups or Windows Firewall to specific administrator IPs. Enforce Network Level Authentication (NLA) and set an account lockout policy (e.g., lock account for 30 minutes after 5 failed attempts).
3.  **SMB Signing Enforcement:**
    *   **Finding:** SMB v2/v3 signing was not enforced, exposing the machine to SMB relay attacks.
    *   **Mitigation:** Enable SMB signing via Group Policy (`Microsoft network server: Digitally sign communications (always)` set to `Enabled`).

---

## 6. Skills & Toolsets Demonstrated

*   **Cloud Security Architecture:** AWS VPC, Subnets, Route Tables, Security Group configuration.
*   **SIEM Administration:** Splunk Enterprise installation, index management, forwarder deployment, inputs.conf scripting, SPL dashboard creation.
*   **Vulnerability Management:** Nessus scanner configuration, vulnerability triage, reporting.
*   **Network Security Monitoring:** `tcpdump` execution, packet capture analysis, Wireshark filters.
*   **Offensive Security Emulation:** Reconnaissance (`Nmap`), exploit framework usage (`Metasploit`), and log trace analysis.
