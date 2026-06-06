Import-Module ActiveDirectory

$password = ConvertTo-SecureString "Summer2024!" -AsPlainText -Force
$user = Get-ADUser -Filter "SamAccountName -eq 'jdoe'" -ErrorAction SilentlyContinue

if (-not $user) {
    New-ADUser `
        -Name "John Doe" `
        -GivenName "John" `
        -Surname "Doe" `
        -SamAccountName "jdoe" `
        -UserPrincipalName "jdoe@serini.lab" `
        -AccountPassword $password `
        -Enabled $true `
        -ChangePasswordAtLogon $false
}

# Idempotent: always enforce the expected password / enabled state, so a user
# left over from a previous (partial) run can still authenticate.
Set-ADAccountPassword -Identity jdoe -Reset -NewPassword $password
Set-ADUser -Identity jdoe -PasswordNeverExpires $true -ChangePasswordAtLogon $false
Enable-ADAccount -Identity jdoe
