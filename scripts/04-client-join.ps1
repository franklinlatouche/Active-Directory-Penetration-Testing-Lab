# Run on each Windows client (WS01, WS02) to point it at the DC and join the domain.
$DcIp = "192.168.1.10"
$DomainName = "lab.local"

$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DcIp

$credential = Get-Credential  # Use Administrator@lab.local
Add-Computer -DomainName $DomainName -Credential $credential -Restart
