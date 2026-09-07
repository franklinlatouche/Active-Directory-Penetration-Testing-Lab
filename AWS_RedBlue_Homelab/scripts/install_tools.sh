#!/bin/bash
set -euo pipefail

# Versions injected by Terraform templatefile — update in terraform.tfvars, not here.
# Splunk: https://www.splunk.com/en_us/download/splunk-enterprise.html
# Nessus: https://www.tenable.com/downloads/nessus
SPLUNK_VERSION="${splunk_version}"
SPLUNK_BUILD="${splunk_build}"
NESSUS_DEB_URL="${nessus_deb_url}"

apt-get update -y
apt-get upgrade -y
apt-get install -y net-tools tcpdump wget curl unzip

# Splunk Enterprise
cd /tmp
wget -O splunk.deb "https://download.splunk.com/products/splunk/releases/$SPLUNK_VERSION/linux/splunk-$SPLUNK_VERSION-$SPLUNK_BUILD-linux-2.6-amd64.deb"
dpkg -i splunk.deb
apt-get install -f -y
/opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd "${splunk_password}"
/opt/splunk/bin/splunk enable boot-start -systemd-managed 1 --accept-license --answer-yes --no-prompt

# Tenable Nessus (Nessus Essentials is free for up to 16 IPs — activate on first login)
wget -O nessus.deb "$NESSUS_DEB_URL"
dpkg -i nessus.deb
apt-get install -f -y
systemctl start nessusd.service
systemctl enable nessusd.service
