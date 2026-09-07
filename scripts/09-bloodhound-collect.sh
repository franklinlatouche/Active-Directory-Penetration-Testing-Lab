#!/usr/bin/env bash
# Exercise 3: BloodHound data collection. Run from Kali.
# Start Neo4j separately first: sudo neo4j console
set -euo pipefail

DC_IP="192.168.1.10"
DOMAIN="lab.local"
USER="jadmin"
PASS="Password123!"

bloodhound-python -u "$USER" -p "$PASS" -d "$DOMAIN" \
    -dc DC01."$DOMAIN" -ns "$DC_IP" -c all

bloodhound
# In the GUI: upload the collected JSON, run "Shortest Path to Domain Admins".
