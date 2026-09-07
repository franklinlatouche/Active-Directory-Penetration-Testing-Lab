# AWS Red Team vs Blue Team Homelab

Cloud-based penetration testing and defensive monitoring lab on AWS. Simulates an attacker (Kali) targeting a vulnerable Windows Server while a SIEM (Splunk + Nessus on Ubuntu) monitors, logs, and detects the activity — all deployed with a single Terraform command.

---

## What You Are Building and How You Access It

**Terraform runs on your local machine** and deploys the entire lab infrastructure automatically. It replaces all AWS Console clicking — no manually launching instances, no configuring security groups through a browser. You run `terraform apply` once and it creates the VPC, subnets, security groups, and all three EC2 instances.

The only two things that still require a browser:
- **IAM user setup** — one-time, creates the credentials Terraform uses to talk to AWS
- **Kali AMI ID lookup** — one-time, find the ID in AWS Marketplace and paste it into your config file

Once the instances are running, you access each one like this:

| Instance | Access Method | What You See |
|----------|---------------|--------------|
| **Kali Linux** | `ssh -i ~/.ssh/redblue-lab-keypair.pem kali@<ip>` | Terminal |
| **Windows Server** | `xfreerdp /v:<ip> /u:Administrator /p:'<password>'` | Windows desktop |
| **Splunk** | Browser `http://<siem-ip>:8000` | Web dashboard |
| **Nessus** | Browser `https://<siem-ip>:8834` | Web dashboard |

---

## Project Directory

```
AWS_RedBlue_Homelab/
├── terraform/
│   ├── providers.tf             — AWS provider declaration
│   ├── variables.tf             — all configurable inputs (region, AMIs, passwords, versions)
│   ├── main.tf                  — all resources: VPC, SGs, EC2s, Flow Logs, CloudTrail
│   ├── outputs.tf               — prints public IPs after deploy
│   └── terraform.tfvars.example — copy to terraform.tfvars and fill in before deploy
├── scripts/
│   ├── install_tools.sh         — SIEM bootstrap: Splunk + Nessus (runs as EC2 user_data)
│   └── splunk_inputs.conf       — Windows Forwarder inputs config (deploy to Windows target)
├── docs/
│   ├── aws_homelab_writeup.md        — full technical writeup with attack/defense scenarios
│   └── aws_homelab_learning_journey.md — step-by-step deployment guide + manual-to-Terraform walkthrough
├── CHANGELOG.md
├── LICENSE
└── .gitignore
```

**Network architecture:**

```
Admin IP ──SSH──────► Kali (10.0.1.10)    ──attacks──► Windows (10.0.1.20)
Admin IP ──RDP──────────────────────────────────────► Windows (10.0.1.20)
Admin IP ──browser──► Splunk :8000 / Nessus :8834   (Ubuntu SIEM 10.0.1.30)
                      Ubuntu SIEM (10.0.1.30) ◄────── Splunk Forwarder port 9997
All traffic  ────────────────────────────────────────► VPC Flow Logs (CloudWatch)
All API calls ───────────────────────────────────────► CloudTrail (S3)
```

---

## First Run

**Prerequisites — install once on your local machine:**

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp/ && sudo /tmp/aws/install
aws --version

# Terraform >= 1.5
sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
terraform --version
```

**AWS account setup (browser, one-time):**
1. IAM → Users → Create User → attach these 6 policies: `AmazonEC2FullAccess`, `AmazonVPCFullAccess`, `AmazonS3FullAccess`, `IAMFullAccess`, `AWSCloudTrail_FullAccess`, `CloudWatchLogsFullAccess`
2. Security credentials → Create access key → CLI → save the key ID and secret

```bash
# Configure CLI with your new credentials
aws configure
# Region: us-east-2 / Output: json

# Create SSH key pair in AWS
aws ec2 create-key-pair \
  --key-name redblue-lab-keypair \
  --region us-east-2 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/redblue-lab-keypair.pem
chmod 400 ~/.ssh/redblue-lab-keypair.pem
```

**Gather AMI IDs:**

```bash
# Ubuntu 22.04 LTS
aws ec2 describe-images --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text --region us-east-2

# Windows Server 2022
aws ec2 describe-images --owners amazon \
  --filters 'Name=name,Values=Windows_Server-2022-English-Full-Base-*' \
            'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text --region us-east-2

# Kali Linux — browser only:
# aws.amazon.com/marketplace → search "Kali Linux" → Continue to Configuration
# Set region to us-east-2 → copy the AMI ID shown on that page → do NOT click Launch
```

**Deploy:**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars        # fill in admin_ip, splunk_password, all three AMI IDs

terraform init
terraform validate
terraform apply              # review plan, type 'yes'
```

Terraform prints the three public IPs when done. Re-display them anytime:

```bash
terraform output
```

**Verify SIEM bootstrap (runs in background, takes 8–12 min):**

```bash
ssh -i ~/.ssh/redblue-lab-keypair.pem ubuntu@<SIEM_IP> \
  'sudo tail -f /var/log/cloud-init-output.log'
# Wait for: nessusd.service enabled — then Ctrl+C
```

**Access web UIs:**
- Splunk: `http://<SIEM_IP>:8000` — login: `admin` / your `splunk_password`
- Nessus: `https://<SIEM_IP>:8834` — choose Nessus Essentials (free), activate on first login

---

## Usage

**Tear down — stop all charges:**
```bash
terraform destroy
```
Instances cost ~$5–15/day running. VPC Flow Logs add ~$0.50/GB ingested, which spikes during active attack simulation. Always destroy when done.

**Re-deploy after destroy:**
```bash
terraform apply
# SIEM bootstrap re-runs — allow 8–12 min before Splunk/Nessus are ready
```

**Get Windows administrator password:**
```bash
WINDOWS_ID=$(aws ec2 describe-instances \
  --filters 'Name=tag:Name,Values=Windows-Target' \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text --region us-east-2)

aws ec2 get-password-data \
  --instance-id "$WINDOWS_ID" \
  --priv-launch-key ~/.ssh/redblue-lab-keypair.pem \
  --region us-east-2 \
  --query 'PasswordData' --output text
```

**RDP to Windows from Ubuntu:**
```bash
sudo apt-get install -y freerdp2-x11
xfreerdp /v:<WINDOWS_IP> /u:Administrator /p:'<PASSWORD>' /w:1920 /h:1080 /cert:ignore
```

**Configure Windows log forwarding (manual, inside RDP session):**
1. Download Splunk Universal Forwarder MSI from splunk.com
2. Install — set receiving indexer to `10.0.1.30:9997`
3. Copy `scripts/splunk_inputs.conf` to `C:\Program Files\SplunkUniversalForwarder\etc\system\local\inputs.conf`
4. Restart: `net stop SplunkForwarder && net start SplunkForwarder`
5. Verify in Splunk: search `index=win-security` — events should appear within 30 seconds

**Update Splunk or Nessus version:**
Edit `terraform.tfvars` — update `splunk_version`, `splunk_build`, and `nessus_deb_url`, then `terraform apply`.

---

## How It Works

**Network:** Single public subnet `10.0.1.0/24` inside a custom VPC. All three instances have pinned private IPs (`10.0.1.10/20/30`). Two security groups: `main_sg` restricts SSH and RDP to your admin IP while allowing unrestricted internal traffic (so Kali can attack Windows freely); `tools_sg` adds Splunk and Nessus web UI ports.

**Bootstrap:** The Ubuntu SIEM runs `install_tools.sh` as EC2 user_data on first boot. Terraform injects `splunk_password`, version strings, and the Nessus download URL via `templatefile()` — no secrets stored in the script file.

**Log pipeline:** Splunk Universal Forwarder on Windows ships Security, Application, and System event logs to the Splunk indexer on port 9997. Index: `win-security`. SPL query to detect brute-force attempts:
```
index=win-security EventCode=4625 | stats count by TargetUserName, IpAddress | sort - count
```

**Visibility:** VPC Flow Logs capture all network-layer traffic metadata into CloudWatch (`/redblue-lab/vpc-flow-logs`, 14-day retention). CloudTrail logs all AWS API calls to S3 (`redblue-lab-trail-<account_id>`). Correlate AWS-level events with host-level Splunk detections for realistic blue team practice.

**Terraform state:** Contains resource IDs and injected secret values. Never commit `terraform.tfstate` — it is gitignored.

---

## Full Deployment Guide

See `docs/aws_homelab_learning_journey.md` for the complete step-by-step walkthrough including AMI lookups, tfvars configuration, post-deploy verification, Windows Splunk Forwarder setup, and a troubleshooting table.
