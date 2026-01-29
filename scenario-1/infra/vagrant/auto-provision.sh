#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$HERE/../ansible" && pwd)"

log() { echo "==> [auto] $*"; }

get_forwarded_5985_port() {
  local vm="$1"
  # Example line: "  5985 (guest) => 2201 (host)"
  # Fields: $1=5985, $2=(guest), $3=>, $4=2201, $5=(host)
  vagrant port "$vm" | awk '/5985 \(guest\)/ {print $4}' | head -n1
}

log "Starting auto-provision (bootstrap Windows IPs, then full lab)."
log "Fetching Vagrant WinRM forwarded ports..."

dc_port="$(get_forwarded_5985_port dc)"
ca_port="$(get_forwarded_5985_port ca)"
win10_port="$(get_forwarded_5985_port win10)"

if [[ -z "${dc_port:-}" || -z "${ca_port:-}" || -z "${win10_port:-}" ]]; then
  echo "ERROR: failed to read forwarded WinRM ports (5985)."
  echo "Try: vagrant port dc; vagrant port ca; vagrant port win10"
  exit 1
fi

log "Ports: dc=127.0.0.1:${dc_port}  ca=127.0.0.1:${ca_port}  win10=127.0.0.1:${win10_port}"
log "Building temporary inventory for bootstrap..."

tmp_inv="$(mktemp -t vagrant-forwarded-winrm.XXXXXX.yml)"
trap 'rm -f "$tmp_inv"' EXIT

cat >"$tmp_inv" <<EOF
all:
  children:
    windows:
      hosts:
        dc:
          ansible_host: 127.0.0.1
          ansible_port: ${dc_port}
          desired_ip: 192.168.58.10
        ca:
          ansible_host: 127.0.0.1
          ansible_port: ${ca_port}
          desired_ip: 192.168.58.20
        win10:
          ansible_host: 127.0.0.1
          ansible_port: ${win10_port}
          desired_ip: 192.168.58.40
      vars:
        ansible_user: vagrant
        ansible_password: vagrant
        ansible_connection: winrm
        ansible_winrm_scheme: http
        ansible_winrm_transport: ntlm
        ansible_winrm_server_cert_validation: ignore
EOF

log "--- Phase 1: Bootstrap Windows private-network IPs (DC, CA, Win10) ---"
log "Running 00-bootstrap-network-forwarded.yml via forwarded WinRM..."
cd "$ANSIBLE_DIR"
ansible-playbook -i "$tmp_inv" playbooks/00-bootstrap-network-forwarded.yml
log "Bootstrap finished."

log "--- Phase 2: Full lab provisioning (site.yml) ---"
log "Plays: 00-network, 01-domain, 02-adcs, 08-ldaps, 03-software-gpo, 04-kali, 05-win10, 06-esc1, 07-test-user."
log "Running site.yml (can take 15–30+ min)..."
ansible-playbook -i inventory.yml playbooks/site.yml
log "Site.yml finished."

log "--- Done. Run: vagrant ssh attacker  (then certipy find ... -vulnerable to check ESC1) ---"

