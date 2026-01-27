#!/bin/bash
# ============================================================================
# Script: Install Attack Tools on Kali
# Purpose: Installs Certipy and other essential AD attack tools
# Run on: Kali attacker VM (192.168.56.50)
# Status: Deprecated (use Ansible playbook `infra/ansible/playbooks/04-kali-tools.yml`)
# ============================================================================

echo "=========================================="
echo "  Installing AD Attack Tools on Kali"
echo "=========================================="
echo ""

# Update system
echo "[*] Updating system packages..."
sudo apt update -qq

# Install Python and dependencies
echo "[*] Installing Python dependencies..."
sudo apt install -y python3 python3-pip python3-dev libssl-dev libffi-dev build-essential

# Install Certipy (THE MAIN TOOL for AD-CS attacks)
echo "[*] Installing Certipy-AD..."
pip3 install certipy-ad

# Install Impacket (for Kerberos attacks, DCSync, etc.)
echo "[*] Installing Impacket..."
pip3 install impacket

# Install CrackMapExec (for network enumeration)
echo "[*] Installing CrackMapExec..."
sudo apt install -y crackmapexec

echo ""
echo "=========================================="
echo "  Verifying Installations"
echo "=========================================="
echo ""

# Verify Certipy
if command -v certipy &> /dev/null; then
    echo "[+] Certipy: INSTALLED"
    certipy --version
else
    echo "[-] Certipy: FAILED"
fi

# Verify Impacket
if command -v impacket-getTGT &> /dev/null; then
    echo "[+] Impacket: INSTALLED"
else
    echo "[-] Impacket: FAILED"
fi

# Verify CrackMapExec
if command -v crackmapexec &> /dev/null; then
    echo "[+] CrackMapExec: INSTALLED"
    crackmapexec --version
else
    echo "[-] CrackMapExec: FAILED"
fi

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Quick Reference Commands:"
echo "  certipy find -h          # Find vulnerable templates"
echo "  certipy req -h           # Request certificates"
echo "  certipy auth -h          # Authenticate with certificates"
echo ""
