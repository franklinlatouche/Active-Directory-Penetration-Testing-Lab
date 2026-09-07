#!/usr/bin/env bash
# Run on the attacker VM (Kali) once, to install everything the exercise scripts need.
set -euo pipefail

sudo apt update && sudo apt upgrade -y
sudo apt install -y bloodhound neo4j crackmapexec \
    impacket-scripts ldapdomaindump enum4linux nmap
