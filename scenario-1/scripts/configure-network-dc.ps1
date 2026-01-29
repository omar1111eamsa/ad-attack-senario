# Network Configuration Script for Domain Controller
# Run this in PowerShell as Administrator on the DC VM

Write-Host "Configuring network adapter for DC..." -ForegroundColor Green

# Find the private network adapter (the one without an IP yet)
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress -notlike "192.168.*" } | Select-Object -First 1

if ($adapter) {
    Write-Host "Found adapter: $($adapter.Name)" -ForegroundColor Yellow
    
    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    
    # Configure static IP (no DefaultGateway; VMware host-only often has no .1)
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress 192.168.58.10 -PrefixLength 24
    
    # Set DNS to itself (will be DC)
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses 192.168.58.10
    
    Write-Host "Network configured successfully!" -ForegroundColor Green
    Write-Host "IP Address: 192.168.58.10" -ForegroundColor Cyan
    
    # Test connectivity
    Write-Host "`nTesting network..." -ForegroundColor Yellow
    Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
} else {
    Write-Host "ERROR: Could not find unconfigured network adapter!" -ForegroundColor Red
    Write-Host "Available adapters:" -ForegroundColor Yellow
    Get-NetAdapter | Format-Table Name, Status, LinkSpeed
}
