# Run on DC01 after AD DS promotion reboot, to confirm the forest is healthy.
Get-Service ADWS
Get-ADDomain
Get-DnsServerZone
nslookup lab.local
