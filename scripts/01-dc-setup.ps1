# Run on the future DC01 VM, as Administrator, before AD DS install.
# Edit these to match your lab's IP scheme.
$IPAddress = "192.168.1.10"
$PrefixLength = 24
$Gateway = "192.168.1.1"
$DomainName = "lab.local"
$NetbiosName = "LAB"

New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress $IPAddress `
    -PrefixLength $PrefixLength -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 127.0.0.1

Rename-Computer -NewName "DC01" -Restart
# VM reboots here. After reboot, run 02-dc-promote.ps1.
