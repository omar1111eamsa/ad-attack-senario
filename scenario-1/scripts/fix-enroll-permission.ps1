Import-Module ActiveDirectory

$configNC = (Get-ADRootDSE).configurationNamingContext
$templateDn = "CN=VulnUserAuth,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"

# Get current ACL
$acl = Get-Acl -Path "AD:$templateDn"

# Get Domain Users SID
$domainUsersSID = (Get-ADGroup "Domain Users").SID
$identity = [System.Security.Principal.SecurityIdentifier]$domainUsersSID

# Enroll GUID
$enrollGuid = [Guid]"0e10c968-78fb-11d2-90d4-00c04f79dc55"

# Create the ACE
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $identity,
    [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
    [System.Security.AccessControl.AccessControlType]::Allow,
    $enrollGuid,
    [DirectoryServices.ActiveDirectorySecurityInheritance]::None
)

# Add the rule
$acl.AddAccessRule($ace)

# Apply the ACL
Set-Acl -Path "AD:$templateDn" -AclObject $acl

Write-Host "Enroll permission added for Domain Users"

# Verify
Get-Acl -Path "AD:$templateDn" | Select-Object -ExpandProperty Access | Where-Object { $_.IdentityReference -like "*Domain Users*" }
