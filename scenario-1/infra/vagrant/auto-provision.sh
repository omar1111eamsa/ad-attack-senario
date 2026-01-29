#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$HERE/../ansible" && pwd)"

get_forwarded_5985_port() {
  local vm="$1"
  # Example line: "  5985 (guest) => 2201 (host)"
  # Fields: $1=5985, $2=(guest), $3=>, $4=2201, $5=(host)
  vagrant port "$vm" | awk '/5985 \(guest\)/ {print $4}' | head -n1
}

dc_port="$(get_forwarded_5985_port dc)"
ca_port="$(get_forwarded_5985_port ca)"
win10_port="$(get_forwarded_5985_port win10)"

if [[ -z "${dc_port:-}" || -z "${ca_port:-}" || -z "${win10_port:-}" ]]; then
  echo "ERROR: failed to read forwarded WinRM ports (5985)."
  echo "Try: vagrant port dc; vagrant port ca; vagrant port win10"
  exit 1
fi

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

echo "==> [auto] Bootstrapping Windows private-network IPs via forwarded WinRM..."
cd "$ANSIBLE_DIR"
ansible-playbook -i "$tmp_inv" playbooks/00-bootstrap-network-forwarded.yml

echo "==> [auto] Running full lab provisioning (site.yml)..."
ansible-playbook -i inventory.yml playbooks/site.yml

echo "==> [auto] Done."

