#!/usr/bin/env bash
# Bootstrap Windows network via Vagrant WinRM port forwarding.
# Run from project root. Use before first 'vagrant provision' if Windows VMs
# don't have 192.168.58.x (VMware doesn't auto-configure secondary adapters).
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$SCRIPT_DIR/../infra/ansible" && pwd)"
cd "$ANSIBLE_DIR"

echo "==> Running Windows network bootstrap (00-windows-network) via forwarded WinRM ports..."
echo "    Limiting to dc,win10 (CA often fails with 'Connection reset'; configure it manually)."
if ansible-playbook -i inventory.yml playbooks/00-windows-network.yml --limit dc,win10; then
  VAGRANT_DIR="$(cd "$SCRIPT_DIR/../infra/vagrant" && pwd)"
  echo ""
  echo "==> DC and Win10 configured. Configuring CA:"
  echo "    Uploading configure-network-ca.ps1 to CA VM..."
  (cd "$VAGRANT_DIR" && vagrant upload "$SCRIPT_DIR/configure-network-ca.ps1" "C:\\Windows\\Temp\\configure-network-ca.ps1" ca) || true
  echo ""
  echo "    1. Open the CA VM (VMware console or RDP)."
  echo "    2. PowerShell as Administrator:"
  echo "       Set-Location C:\\Windows\\Temp; .\\configure-network-ca.ps1"
  echo "    3. Then: cd scenario-1/infra/vagrant && vagrant provision"
  exit 0
fi

echo ""
echo "==> Bootstrap failed. Configure all Windows VMs manually (DC, CA, Win10):"
echo "    Run configure-network-dc.ps1, configure-network-ca.ps1, configure-network-win10.ps1"
echo "    on each VM (PowerShell as Admin). Then: vagrant provision"
exit 1
