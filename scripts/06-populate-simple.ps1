# Lighter alternative to BadBlood: a handful of OUs, users, and one
# Kerberoastable service account with an SPN. Run on DC01.
$Password = ConvertTo-SecureString "Password123!" -AsPlainText -Force

New-ADOrganizationalUnit -Name "Departments" -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "IT" -Path "OU=Departments,DC=lab,DC=local"
New-ADOrganizationalUnit -Name "HR" -Path "OU=Departments,DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Finance" -Path "OU=Departments,DC=lab,DC=local"

New-ADUser -Name "John Admin" -SamAccountName "jadmin" `
    -UserPrincipalName "jadmin@lab.local" `
    -Path "OU=IT,OU=Departments,DC=lab,DC=local" `
    -AccountPassword $Password -Enabled $true

New-ADUser -Name "Bob User" -SamAccountName "buser" `
    -UserPrincipalName "buser@lab.local" `
    -Path "OU=HR,OU=Departments,DC=lab,DC=local" `
    -AccountPassword $Password -Enabled $true

# Service account with SPN, for Kerberoasting practice.
New-ADUser -Name "SQL Service" -SamAccountName "sqlsvc" `
    -UserPrincipalName "sqlsvc@lab.local" `
    -Path "OU=IT,OU=Departments,DC=lab,DC=local" `
    -AccountPassword $Password -Enabled $true

setspn -a MSSQLSvc/SQLSERVER.lab.local:1433 LAB\sqlsvc
