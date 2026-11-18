# Prompts — proxmox-lab

Useful prompts for the kiro agent working on this project.

---

## Initial setup prompt

> I am starting a new project called proxmox-lab. Please read the steering files and check your messages to understand the landscape you are part of. Then help me set up the project structure.

---

## Deploy prompt

> Commit, release, and deploy this change.

---

## Audit prompt

> Check that this project is consistent with the landscape conventions (version file, changelog, branch, deploy scripts).


--------------------------------------------
I have a proxmox cluster that I can access with ssh proxmox and which has this config:

Host — pve (192.168.0.8)
Proxmox VE 9.2.2, kernel 7.0.2-6-pve.

Storage: local-lvm (LVM-thin, ~2.6 TB free), local dir for ISOs/imports.

Bridges: vmbr0 (LAN/mgmt), vmbr1 (isolated lab).

Imported images staged in /var/lib/vz/images-import/.

VM 100 — defender (Debian 12 "bookworm")
4 GB RAM / 2 cores / 40 GB disk. Built from the Debian genericcloud qcow2 + cloud-init.

User labadmin, SSH-key auth (keys: id_ed25519_toto, _toto_local, devlin).

NICs: eth0 10.10.10.5/24 (lab sensor), eth1 192.168.0.212/24 (DHCP, mgmt).

Services:
  - Suricata 7.0.10 — IDS sniffing eth0, HOME_NET 10.10.10.0/24,
    ET Open ruleset (~53k rules), logs to /var/log/suricata/eve.json.
  - EveBox 0.31.0 — web UI on :5636, sqlite backend, tails eve.json.
  - dnsmasq — DHCP for the lab net, bound to eth0 only, hands out
    10.10.10.100-199 + a static lease pinning the target to .11.

VM 110 — target-metasploitable (Metasploitable 2)
1 GB RAM / 1 core / 8 GB disk. Imported VMDK, attached as IDE (ide0)
  — the 2012-era kernel cannot boot from virtio-scsi (it dropped to initramfs
  until switched to IDE).

Single NIC net0 (e1000) on vmbr1, address 10.10.10.11 via DHCP.

Deliberately vulnerable: vsftpd 2.3.4 backdoor, UnrealIRCd, old Samba, bindshell
  on 1524, DVWA/Mutillidae web apps, etc. Default creds msfadmin/msfadmin.

Never place this VM on vmbr0.
