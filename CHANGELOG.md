## 2026-09-07: Repo scaffold

**Added**
- Repo structure: `docs/`, `scripts/`, README, CHANGELOG, .gitignore
- 14 numbered PowerShell/Bash scripts extracted from the writeup's inline
  snippets, covering DC build, domain population (BadBlood and simple),
  enumeration, credential attacks, BloodHound collection, Kerberoasting,
  lateral movement, Golden Ticket, and blue-team logging
- README with build order, usage, and architecture summary

**Fixed**
- `impacket-ticketer` invocation in `scripts/12-golden-ticket.sh` now
  includes the required target-username argument (missing in the doc's
  PDF-wrapped original)
