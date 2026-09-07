# Active Directory Penetration Testing Lab

Self-hosted Active Directory environment for practicing offensive and
defensive AD security: domain controller build, realistic domain
population, then a full attack chain against it -- enumeration,
Kerberoasting, AS-REP Roasting, BloodHound-driven privilege escalation
mapping, lateral movement, and Golden Ticket persistence, with matching
blue-team detection steps.

---

## Project Directory

```
Active_Directory_Pentest_Lab/
├── docs/
│   └── Active_Directory_Penetration_Testing_Lab.md  - full build-and-attack writeup
├── scripts/
│   ├── 01-dc-setup.ps1              - static IP + rename DC01
│   ├── 02-dc-promote.ps1            - install AD DS, promote forest
│   ├── 03-dc-verify.ps1             - post-promotion health checks
│   ├── 04-client-join.ps1           - join a Windows client to the domain
│   ├── 05-kali-setup.sh             - install attacker tooling on Kali
│   ├── 06-populate-badblood.ps1     - BadBlood: 2,500+ users, realistic ACLs
│   ├── 06-populate-simple.ps1       - lighter OU/user/SPN seed, no BadBlood
│   ├── 07-enum.sh                   - network/SMB/LDAP enumeration
│   ├── 08-cred-attacks.sh           - password spraying + AS-REP Roasting
│   ├── 09-bloodhound-collect.sh     - BloodHound data collection + GUI
│   ├── 10-kerberoast.sh             - request + crack service tickets
│   ├── 11-lateral-movement.sh       - pass-the-hash + PSExec
│   ├── 12-golden-ticket.sh          - dump krbtgt, forge + use Golden Ticket
│   └── 13-blue-team-logging.ps1     - enable PowerShell/cmdline audit logging
├── CHANGELOG.md
└── .gitignore
```

---

## First Run

**Prerequisites (local machine):**
- Virtualization platform: VMware Workstation/Player, VirtualBox, or Proxmox
- Windows Server 2019/2022 evaluation ISO (Microsoft Evaluation Center)
- Windows 10/11 evaluation ISO
- Kali Linux ISO (kali.org)
- 16GB+ RAM host, 200GB+ free disk, all VMs on one isolated virtual network

**Build order:**

1. Create three (or more) VMs per `docs/Active_Directory_Penetration_Testing_Lab.md` §"Step-by-Step Installation" (DC01, WS01/WS02, ATTACKER).
2. On DC01: run `scripts/01-dc-setup.ps1`, reboot, then `scripts/02-dc-promote.ps1`, reboot, then `scripts/03-dc-verify.ps1`.
3. On each client: run `scripts/04-client-join.ps1`.
4. On ATTACKER (Kali): run `scripts/05-kali-setup.sh`.
5. Populate the domain from DC01 -- either `scripts/06-populate-badblood.ps1` (realistic, 20-30 min) or `scripts/06-populate-simple.ps1` (fast, minimal).
6. Verify: from Kali, `crackmapexec smb <DC_IP>` should return the domain name.

All IPs default to the `192.168.1.0/24` scheme in the doc -- edit the variables at the top of each script if your lab uses a different range.

---

## Usage

Run the numbered attack scripts from Kali in order against the populated
domain:

```bash
./scripts/07-enum.sh
./scripts/08-cred-attacks.sh
./scripts/09-bloodhound-collect.sh
./scripts/10-kerberoast.sh
./scripts/11-lateral-movement.sh <NTLM_HASH>
./scripts/12-golden-ticket.sh
```

Then, on DC01, run `scripts/13-blue-team-logging.ps1` and correlate the
generated Event IDs (4768/4769 for Kerberoasting, 4624/4625 for lateral
movement) against what each attack script triggered.

Full technique-by-technique detail, MITRE ATT&CK mapping, troubleshooting
table, and portfolio/resume writeup live in
`docs/Active_Directory_Penetration_Testing_Lab.md`.

---

## How It Works

**Domain:** `lab.local` (NetBIOS `LAB`), forest/domain functional level
Windows Server 2016+. OUs: `Departments/{IT,HR,Finance,Sales}`,
`Workstations`, `Servers`, `Service Accounts`.

**Attack surface:** the `sqlsvc` service account (or BadBlood's generated
accounts) carries an SPN, making it Kerberoastable via `impacket-GetUserSPNs`
+ `hashcat -m 13100`. BloodHound maps the ACL graph BadBlood creates to find
privilege-escalation paths to Domain Admin without brute-forcing anything.
Golden Ticket persistence relies on dumping `krbtgt`'s NTLM hash via
`impacket-secretsdump` once Domain Admin is reached, then forging TGTs with
`impacket-ticketer`.

**Detection:** Windows Security event log is the source of truth --
4768/4769 for ticket requests (Kerberoasting), 4624/4625 for logons
(lateral movement, Golden Ticket misuse). `scripts/13-blue-team-logging.ps1`
turns on PowerShell script-block logging and command-line auditing so those
events carry enough context to investigate.

Two commands in the doc are flagged as reconstructed from PDF line-wraps
(`Install-ADDSForest`'s `-SafeModeAdministratorPassword` line,
`impacket-ticketer`'s target-username argument) -- the scripts here already
carry the corrected/verified form.
