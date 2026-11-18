# Catch-up — proxmox-lab (read this first)

Handoff for the Kiro agent working in this repo. It covers the project's state as of
**2026-11-18**, the facts you can't easily rediscover, and the traps already hit.
Details and the topology diagram are in [docs/architecture.md](docs/architecture.md).
How the host was installed is in [docs/host-install-dual-boot.md](docs/host-install-dual-boot.md).

---

## 1. What this project is

An **isolated security lab** on a Proxmox host (`pve`). The owner is an IT professional
who wants to learn to **detect and defend against attacks** so the skills transfer to
protecting real systems at work. The loop is: attack a vulnerable target, watch it in an
IDS, harden, re-test.

The owner is new to Suricata. Explain what alerts mean. Don't assume familiarity.

## TL;DR — what's still open (2026-11-18)

Everything from the owner's 6-item list is done or in progress except:

- [ ] **Waiting on another agent**: a message was sent to the inventory agent
  (`~/.kiro/messages/inbox/inventory/2026-11-18_proxmox-lab_register-new-project.md`)
  to register `pve`/`proxmox-lab` in `~/inventory/inventory.csv` + regenerate
  `index.html`. Check whether it's been applied yet (look for a reply in this
  project's inbox, or just check the CSV).
- [ ] **UnrealIRCd backdoor** (port 6667, CVE-2010-2075) on Metasploitable — didn't
  trigger reliably over raw sockets. Worth retrying with Metasploit itself.
- [ ] **Samba usermap_script exploit** on Metasploitable — not attempted yet.
- [ ] **Wrap-up EveBox review** — a written summary of what did/didn't alert across
  all the exploit traffic run so far, for the owner's learning.
- [ ] **Windows/AD target** — not built. Would need a Windows ISO/license decision
  with the owner first.
- [ ] **Commit + push** this repo (`proxmox-lab`) — scripts and docs are written but,
  as of the start of this session, nothing had been committed yet. Check `git log`/
  `git status` to see if this happened before the handoff.
- [ ] Optional/deferred by owner choice: `boot-windows` helper, router reservation for
  `192.168.0.8` itself, Suricata/EveBox boot-time health checks (item 7, skipped on
  purpose).

Everything else (scan/recon detection tuning, vsftpd exploit verified, lab scripted
in `scripts/`, defender LAN IP pinned, Juice Shop + symfonos:1 targets built, Proxmox
repo switch + dist-upgrade + reboot + baseline snapshots) is **done** — see section 7
for details and dates.

## 2. Current state

| Item | State |
|---|---|
| Host `pve` (Proxmox VE 9.2.28, kernel 7.0.14-29-pve) | Up at **192.168.0.8**, web UI https://192.168.0.8:8006. On `pve-no-subscription` repo (switched 2026-11-18). |
| `vmbr0` | Bridged to physical NIC `nic0`, LAN 192.168.0.0/24, gateway 192.168.0.1 |
| `vmbr1` | **Isolated lab bridge**: `bridge-ports none`, no address, no gateway |
| VM 100 `defender` (Debian 12) | Running. eth0 `10.10.10.5/24` (lab, static), eth1 `192.168.0.212` (LAN, DHCP lease) |
| on defender: Suricata 7.0.10 | Active. Sniffs eth0, HOME_NET `10.10.10.0/24`, ET Open (~53k rules), logs `/var/log/suricata/eve.json` |
| on defender: EveBox 0.31.0 | Active. **http://192.168.0.212:5636**, sqlite backend, no auth (lab only) |
| on defender: dnsmasq | Active. DHCP on eth0 only, range `.100-.199`, advertises **no gateway/DNS**, static leases `.11` and `.31` by MAC |
| VM 110 `target-metasploitable` | Running at **10.10.10.11**, only NIC on `vmbr1` |
| VM 120 `target-juiceshop` | Running at **10.10.10.21:3000** (OWASP Juice Shop, Docker), only NIC on `vmbr1` |
| VM 130 `target-symfonos1` | Running at **10.10.10.31** (VulnHub symfonos:1), only NIC on `vmbr1` |
| VM 140 `redteam` | Exists on the host, created directly by the owner. **Out of scope** — not managed, documented in detail, or touched by this project. Dual-homed (lab net + LAN with firewall). |

Detection loop verified and improved: an nmap `-sS -sV` scan originally produced ~1000
flow events but only **1 signature alert** (ET Open has no generic port-scan
preprocessor). Fixed with custom `scripts/suricata/local.rules` — the same scan now
produces dozens of alerts. Exploit traffic has also been run for real: the vsftpd 2.3.4
backdoor on Metasploitable was triggered successfully (confirmed root shell), and
Suricata caught it via a response-pattern signature, not a backdoor-specific one — a
good illustration of detecting the symptom rather than the trigger. The UnrealIRCd
backdoor (port 6667) did not reproduce reliably and is parked.

The lab is now scripted — see `scripts/` (bridge creation, VM creation per host,
defender provisioning, including the `local.rules` file). Still **not committed to
git** (see section 7/8) — ask before committing, per section 8.

## 3. Safety rules (non-negotiable)

1. **Never attach the target (VM 110), or any other vulnerable VM, to `vmbr0`.** `vmbr1`
   having no physical port is the containment boundary.
2. Keep dnsmasq advertising no gateway and no DNS. Don't add routing or NAT between
   `10.10.10.0/24` and the LAN.
3. Only the defender is dual-homed. If something on `vmbr1` needs internet, stage files
   via the defender or the Proxmox host. Don't give targets a route.
4. Don't touch Windows. The Windows SSD and the 1.8 TB WD disk are off-limits. Proxmox
   lives on the 3 TB Seagate (serial `W502PDPF`).
5. Confirm before destructive or hard-to-reverse actions: wiping disks, deleting VMs or
   LVs, changing `vmbr0` (it is the management link; a mistake locks the owner out).
   Back up `/etc/network/interfaces` first. A timestamped backup from the `vmbr1` change
   exists at `/etc/network/interfaces.bak-20261116-014658` on the host.

**Out of scope, by decision:** installing or operating "Artex" (an AI-assisted offensive
pentest tool the owner mentioned). The agent declined because it couldn't identify the
tool. It was described as actively attacking the owner's systems, which makes it
operating offensive tooling rather than lab defense. The learning goal is reachable
with standard tools (nmap, Metasploit, Kali) and the Suricata loop. Don't reopen this
unless the owner raises it; if they do, hold the same line. The owner was also advised
that if real company systems are under live attack, the urgent work is on those
systems (logs, patching, credential rotation), and the lab doesn't replace it.

## 4. How to drive the environment

**SSH needs the agent loaded first.** `sshagent` is a shell alias, and the
`execute_bash` tool doesn't load the profile. Every command must start with:

```bash
source ~/.bash_aliases && sshagent >/dev/null 2>&1
```

Env doesn't persist between tool calls, so repeat it in each call.

```bash
SSHX="ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@192.168.0.8"
DEF="ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new labadmin@192.168.0.212"
$SSHX 'qm list'
$DEF 'sudo systemctl status suricata evebox dnsmasq'
```

- Proxmox host: `root@192.168.0.8`, key auth only.
- Defender: `labadmin@192.168.0.212` (passwordless sudo), keys preseeded via cloud-init.
- Target (VM 110): no SSH or agent from our side. Console only via the Proxmox web UI
  (`msfadmin`/`msfadmin`, public default creds). It has an old kernel and uses `ifconfig`.
- Don't run long or hanging commands without `timeout`. An un-timed ssh to a host
  that's mid-reboot hung a tool call for 2 minutes.
- The owner has a Belgian (AZERTY) keyboard. The Metasploitable console is US-layout
  until `sudo loadkeys be` is run.

## 5. Gotchas already solved (don't re-learn)

- **Target dropped to `(initramfs)`**: the imported Metasploitable VMDK can't boot from
  `virtio-scsi`. Fix: attach as **IDE** (`ide0`, `boot: order=ide0`). Already applied.
- **`apt install suricata` failed on Debian 12**: unmet `libhtp2` dependency (Suricata
  comes from bookworm-backports). Fix: `apt-get install -t bookworm-backports suricata`.
- **EveBox apt repo setup failed silently**: the cloud image has no `gpg`. Install
  `gnupg` first. EveBox's default config expects Elasticsearch, so `/etc/evebox/evebox.yaml`
  was rewritten to `database: sqlite` with the eve.json input enabled.
- **Stale `known_hosts`** for `192.168.0.212` (reused DHCP IP) triggers a scary
  "host identification changed" warning. Clear with `ssh-keygen -R <ip>`.
- `download.proxmox.com` HEAD requests fail from the host while general internet works.
  Don't treat that as an outage.
- Proxmox host has no `unzip` by default (installed). Images are staged in
  `/var/lib/vz/images-import/` (Metasploitable zip/VMDK, Debian cloud qcow2). They can be
  deleted to reclaim space once VMs are built.
- The target's web apps (DVWA, Mutillidae) are unreachable from the LAN by design. Use
  an SSH SOCKS proxy through the defender: `ssh -D 1080 labadmin@192.168.0.212`.

## 6. Decisions already made (don't re-litigate)

- Lab network is a **bridge with no uplink**, subnet `10.10.10.0/24`, deliberately
  different from the LAN.
- IDS is **Debian + Suricata**, not Security Onion. Security Onion is heavy (~16 GB RAM)
  and was deferred, not rejected. UI is **EveBox**, not ELK, for a single-sensor lab.
- Defender has a second NIC on `vmbr0` for management and package installs.
- Storage: ext4 on LVM-thin (`local-lvm`, ~2.6 TB free). 4 cores / 31 GB RAM on the host.
- Windows stays on its own disks, boots via UEFI order (Proxmox default, F8 for Windows).
  Idea offered but not yet set up: a `boot-windows` helper using `efibootmgr -n <entry>`
  (one-shot `BootNext`) so Windows needs no BIOS visit.

## 7. Open items / roadmap

Owner said to do items 1-6 in sequence (skipping 7 for now). Status:

1. **Exploit-style traffic + detection tuning — mostly done.** Scan/recon detection
   added (`local.rules`). vsftpd backdoor exploited and confirmed. UnrealIRCd backdoor
   parked (didn't reproduce reliably — worth retrying with Metasploit itself). Samba
   usermap_script and a wrap-up EveBox review of what did/didn't alert are still open.
2. **Make the lab reproducible — done.** Scripts in `scripts/` cover bridge creation,
   defender creation + provisioning, and all three target VMs. Not yet committed to git.
3. **Static LAN IP for the defender — done.** The owner pinned `192.168.0.212` via a
   router-side DHCP reservation on MAC `BC:24:11:7B:A6:AB` (2026-11-18). No VM-side
   change was needed; the address itself didn't change, it's just stable now.
4. **Inventory**: owner confirmed OK to proceed. `inventory.csv`/`index.html` are
   owned by the inventory agent (per `landscape.md` — a direct external edit caused a
   corruption incident once). A message was sent to
   `~/.kiro/messages/inbox/inventory/` (2026-11-18) with the proposed row (suggested
   ID 28, category `Personal/security`) and the `pve` host-table entry. **Waiting on
   the inventory agent to apply it** — not yet reflected in the CSV/HTML.
5. **More targets — done.** Added `target-juiceshop` (OWASP Juice Shop, 10.10.10.21:3000)
   and `target-symfonos1` (VulnHub symfonos:1, 10.10.10.31). Note: Metasploitable
   already bundles DVWA/Mutillidae, so a separate DVWA VM wasn't needed. A Windows/AD
   target remains a good future addition (bigger attack-surface gap than another Linux
   box) but wasn't built this round.
6. **Proxmox post-install chores — done** (2026-11-18). Switched to
   `pve-no-subscription`, disabled `pve-enterprise.sources` and `ceph.sources`
   (`Enabled: no`, backups in `/root/apt-sources-backup-20261118/` on the host).
   Ran `apt dist-upgrade` (213 packages incl. a kernel bump to `7.0.14-29-pve` and
   `pve-manager` 9.2.2→9.2.28) — installed cleanly, no broken packages. Rebooted onto
   the new kernel (confirmed via `pveversion`); VMs 100/110/120/130 don't auto-start,
   so they were started back up manually and verified healthy. Baseline snapshots
   (`baseline-20261118`) taken on VMs 100/110/120/130 (not 140 — out of scope). Note:
   the Metasploitable (110) baseline is **not pristine** — the vsftpd backdoor
   exploit from item 1 was already run against it before this snapshot.
7. Optional (explicitly deferred by owner): host `boot-windows` helper (section 6);
   reserve `192.168.0.8` in the router; Suricata/EveBox boot-time health checks.

### VM 140 `redteam` — explicitly out of scope
The owner created VM 140 (`redteam`) directly on the host, outside of this project's
scripts and documentation. Its config (dual-homed: lab net `vmbr1` with firewall off,
LAN `vmbr0` with firewall on, 12 GB RAM, 80 GB disk, UEFI) closely matches a build the
agent was asked about and **declined** earlier in this project (an autonomous
AI-assisted offensive pentest tool referred to as "Artex" — see the out-of-scope note
in section 3). The owner confirmed they created VM 140 manually. The agent is not managing,
provisioning, operating, or documenting what runs on VM 140, and should keep holding
that line if asked again. This is noted here only so VM 140's existence on the host
isn't mistaken for an anomaly in a future session.

## 8. Repo conventions

- Scaffolded with the standard landscape layout (`VERSION`, `CHANGELOG.md`,
  `.kiro/steering/release-process.md`). Follow the release process steering and use
  `main` only.
- `mynotes-proxmox-lab.md` and `prompts.md` are generic scaffold templates. The
  venv/deploy sections don't apply to this project. Prune them when convenient.
- No secrets in git. Keep passwords and tokens out of docs (the old
  `utils/mynotes-proxmox.sh` has a credential line for the previous Esprimo VM setup;
  don't copy it here).
- The old `utils/mynotes-proxmox.sh` covers a different, earlier Proxmox (VirtualBox on
  an Esprimo at 192.168.0.219). It is not part of this project.
- Don't commit unless the owner asks. Nothing in this repo has been committed yet.
