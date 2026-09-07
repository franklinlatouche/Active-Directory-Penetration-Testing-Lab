# Run on DC01 as Domain Admin + Schema Admin. Populates the domain with
# 2,500+ users, 500+ groups, and intentional misconfigurations.
Set-ExecutionPolicy Unrestricted -Scope Process

New-Item -Path "C:\BadBlood" -ItemType Directory -Force

$url = "https://github.com/davidprowe/BadBlood/archive/refs/heads/master.zip"
Invoke-WebRequest -Uri $url -OutFile "C:\BadBlood\BadBlood.zip"
Expand-Archive -Path "C:\BadBlood\BadBlood.zip" -DestinationPath "C:\BadBlood"

cd C:\BadBlood\BadBlood-master
.\Invoke-BadBlood.ps1
# Confirm test-environment prompt, then wait 20-30 min for completion.
