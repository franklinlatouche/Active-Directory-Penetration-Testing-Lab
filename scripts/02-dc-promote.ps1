# Run on DC01 after reboot from 01-dc-setup.ps1. Requires AD DS role + promotion.
# CHANGE the SafeModeAdministratorPassword before running in any environment
# that isn't fully isolated.
$DomainName = "lab.local"
$NetbiosName = "LAB"

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Import-Module ADDSDeployment
Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $NetbiosName `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDNS:$true `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
    -Force:$true
# Server reboots automatically. After reboot, run 03-dc-verify.ps1.
