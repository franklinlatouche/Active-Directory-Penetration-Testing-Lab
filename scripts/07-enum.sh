#!/usr/bin/env bash
# Exercise 1: network discovery and enumeration. Run from Kali.
set -euo pipefail

SUBNET="192.168.1.0/24"
DC_IP="192.168.1.10"

nmap -sn "$SUBNET"
nmap -sV -sC -p- "$DC_IP"

crackmapexec smb "$DC_IP"
enum4linux -a "$DC_IP"

ldapsearch -x -h "$DC_IP" -b "DC=lab,DC=local"
