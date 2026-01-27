Import-Module ActiveDirectory

$templateName = "VulnUserAuth"
$templateDisplayName = "Vulnerable User Authentication"
$configNC = (Get-ADRootDSE).configurationNamingContext
$templatesPath = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
$templateDn = "CN=$templateName,$templatesPath"
$oidPath = "CN=OID,CN=Public Key Services,CN=Services,$configNC"

# Create template if missing by cloning "User"
$existing = Get-ADObject -SearchBase $templatesPath -LDAPFilter "(cn=$templateName)" -ErrorAction SilentlyContinue
if (-not $existing) {
    $source = Get-ADObject -SearchBase $templatesPath -LDAPFilter "(cn=User)" -Properties *

    # Create unique OID for new template
    $guid = [Guid]::NewGuid().ToString()
    $oidValue = "1.3.6.1.4.1.311.21.8.$(Get-Random -Minimum 100000 -Maximum 999999)"
    New-ADObject -Name $guid -Type msPKI-Enterprise-Oid -Path $oidPath -OtherAttributes @{
        "msPKI-Cert-Template-OID" = $oidValue
        "DisplayName" = $templateDisplayName
        "flags" = 1
    }

    $attrs = @{
        "displayName" = $templateDisplayName
        "flags" = $source.flags
        "pKIExpirationPeriod" = $source.pKIExpirationPeriod
        "pKIOverlapPeriod" = $source.pKIOverlapPeriod
        "pKIDefaultKeySpec" = $source.pKIDefaultKeySpec
        "pKIKeyUsage" = $source.pKIKeyUsage
        "pKIMaxIssuingDepth" = $source.pKIMaxIssuingDepth
        "pKIExtendedKeyUsage" = $source.pKIExtendedKeyUsage
        "msPKI-RA-Signature" = $source.'msPKI-RA-Signature'
        "msPKI-Enrollment-Flag" = $source.'msPKI-Enrollment-Flag'
        "msPKI-Private-Key-Flag" = $source.'msPKI-Private-Key-Flag'
        "msPKI-Minimal-Key-Size" = $source.'msPKI-Minimal-Key-Size'
        "msPKI-Template-Schema-Version" = $source.'msPKI-Template-Schema-Version'
        "msPKI-Template-Minor-Revision" = $source.'msPKI-Template-Minor-Revision'
        "msPKI-Template-Major-Revision" = $source.'msPKI-Template-Major-Revision'
        "msPKI-Cert-Template-OID" = $oidValue
        # ENROLLEE_SUPPLIES_SUBJECT
        "msPKI-Certificate-Name-Flag" = ($source.'msPKI-Certificate-Name-Flag' -bor 1)
    }

    if ($source.pKIDefaultCSPs) { $attrs["pKIDefaultCSPs"] = $source.pKIDefaultCSPs }
    if ($source.pKICertificatePolicy) { $attrs["pKICertificatePolicy"] = $source.pKICertificatePolicy }
    if ($source.pKICriticalExtensions) { $attrs["pKICriticalExtensions"] = $source.pKICriticalExtensions }

    New-ADObject -Name $templateName -Type pKICertificateTemplate -Path $templatesPath -OtherAttributes $attrs
}

# Ensure Domain Users can Enroll
$acl = Get-Acl "AD:$templateDn"
$domainUsers = New-Object System.Security.Principal.NTAccount("SERINI", "Domain Users")
$enrollGuid = [Guid]"a05b8cc2-17bc-4802-a710-e7c15ab866a2"
$rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($domainUsers, "ExtendedRight", "Allow", $enrollGuid)
$acl.AddAccessRule($rule)
Set-Acl -Path "AD:$templateDn" -AclObject $acl
