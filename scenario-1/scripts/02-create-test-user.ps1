Import-Module ActiveDirectory

$user = Get-ADUser -Filter "SamAccountName -eq 'jdoe'" -ErrorAction SilentlyContinue
if (-not $user) {
    $password = ConvertTo-SecureString "Summer2024!" -AsPlainText -Force
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
