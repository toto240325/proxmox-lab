# Proxmox + Windows Dual-Boot — Context Handoff for Next Kiro Session

> **STATUS UPDATE (2026-11-17): INSTALL COMPLETE.** Everything below is the historical
> plan. Actual outcome: Proxmox VE 9.2.2 installed on the 3 TB Seagate, boots by default
> (UEFI order: proxmox #1, Windows Boot Manager #2). Management IP is **192.168.0.8**
> (not the `192.168.1.50` suggested below; the LAN is `192.168.0.0/24`). Passwordless SSH
> works via the `sshagent` alias. Current lab state: see [architecture.md](architecture.md)
> and [../catchup.md](../catchup.md). Sections 4–5 ("open decisions", "current state") are obsolete.

> Purpose: give the next Kiro instance (and the user) full context to continue a Proxmox-over-Windows dual-boot project without re-investigating. Read this first.

---

## 1. The goal

Install **Proxmox VE** alongside the existing **Windows 11** on this machine, as a UEFI dual-boot.
- Proxmox is the **primary, 24/7** workload.
- Windows must remain **fully functional** but is used rarely.
- Proxmox goes on **its own dedicated HDD** (Disk 2, the 3 TB Seagate).

## 2. Machine / hardware facts (verified from Windows)

- Model: **MEDION Akoya P5330 E MD8876** · Mainboard **MEDION H110H4-EM** (v2.0)
- Firmware: **AMI UEFI**, BIOS ver `110EMW0X.102`, release 2016-03-04 → **UEFI boot mode confirmed** (`BiosFirmwareType = Uefi`)
- Chipset: Intel **H110** (Skylake-era, 6th gen Intel)
- RAM: **32 GB**
- Firmware keys for this board:
  - Enter UEFI setup: **Del** (fallback **F2**) at power-on
  - One-time boot menu: **F8** (fallback **F11**) at power-on

### Disk layout (verified)
| Physical disk | Model / ID | Size | Role | Touch? |
|---|---|---|---|---|
| **Disk 1** | INTENSO **SSD** | 512 GB | **Active Windows boot**: EFI System partition + `C:` + Recovery. `IsBoot`/`IsSystem` live here. | **NEVER touch** |
| **Disk 0** | WD **WD20EZRX** (1.8 TB) | 1863 GB | Data + sync roots. `D:` (data, now ~288 GB free after receiving G:'s data), `E:` BootD (an OLD/leftover Windows install, 87 GB — has pagefile/hiberfil/swapfile, BCD backups), `F:` Recover (60 GB). Tangled with Users/Program Files/OneDrive/GoogleDrive/iCloud. | **Leave alone** (keep Windows data) |
| **Disk 2** | Seagate **ST3000VX000-1ES166**, **serial `W502PDPF`** | 2794 GB (~2.8 TiB) | **TARGET for Proxmox.** Now effectively empty. | **Erase & install Proxmox here** |

> Positive-ID the target by **serial `W502PDPF`** and/or **~2.8 TB** capacity. Do NOT rely on drive letter or /dev/sdX ordering.

## 3. Key decisions already made (do not re-litigate unless user asks)

1. **Which disk for Proxmox:** the **3 TB Seagate (Disk 2)**. Reason: it held only bulk/junk data (easy to clear), and it has nothing boot-related, unlike the 1.8 TB which carries an old Windows install. (User's original instinct was backwards; this was analyzed and agreed.)
2. **Data migration:** DONE by user — everything useful copied **G: → D:**. G: is now ~empty (2297 of 2306 GB free). Treat anything still on G: as disposable.
3. **Dual-boot method:** **Separate ESPs / separate bootloaders**, chosen via **UEFI boot order**. Proxmox default; press **F8** to boot Windows occasionally. NOT a shared GRUB os-prober menu. Rationale: isolation — neither OS's updates can break the other's boot.
4. **Install style:** **Do NOT unplug** the other disks. Safety comes from strict target-by-serial discipline + post-install verification. (User explicitly chose no-unplug.)
5. **Filesystem:** **ext4 on LVM** (not ZFS). Suggested installer params: `maxroot` 60 GB, `swapsize` 8 GB, full disk for the rest (thin pool for VMs/CTs).

## 4. Decisions still OPEN (ask the user)

- **Static IP vs DHCP** for Proxmox management NIC (recommended: static, e.g. `192.168.1.50/24`).
- Confirm **maxroot 60 GB / swap 8 GB** or adjust.
- Whether to proceed step-by-step with the user at the physical machine now.

## 5. Current state / where we are

- Analysis + disk cleanup: **done**.
- Data moved G:→D: **done** (by user).
- Proxmox USB installer: **DONE**. Created with Rufus on this machine.
  - Target ISO: **Proxmox VE 9.2** (amd64/x86-64), file `proxmox-ve_9.2-1.iso` (~1.7 GB), based on Debian 13 "Trixie", kernel 7.0.
  - USB: 28.9 GB "Generic Flash Disk", **serial `24042793090125`** (was previously a Windows installer stick; now overwritten).
  - Verified from Windows: ISOhybrid/DD-mode layout present — partition 2 is a GPT **ESP** (type `c12a7328-...`) → UEFI-bootable; ~1.6 GB HFS payload partition present. Windows cannot read the payload FS (normal for a DD-written Linux ISO); final integrity confirmation = it reaching the installer menu when booted.
  - Rufus settings used: GPT / UEFI (non-CSM), DD Image mode.
- Disk 2 **not yet wiped** — still has old GPT: tiny Reserved, `G:` 2306 GB, plus leftover `J:` fut-pve-390G, `K:` fut-w11-70G, `L:` fut-deb-30G (these `fut-*` partitions were pre-made by someone earlier; they are just leftover empty/near-empty partitions, NOT an existing Proxmox install).
- Proxmox: **not yet installed**.
- Next action when ready: Phase 1 (clear Disk 2 — verify by serial `W502PDPF` first), then boot the USB (F8 → UEFI entry).

## 6. Risks / gotchas to remember

- **Biggest risk:** the Debian/Proxmox installer could put GRUB on the wrong ESP (the Windows SSD) if the target is misselected. Mitigate: select target strictly by 2.8 TB / serial `W502PDPF`; verify with `efibootmgr -v` post-install that `proxmox` and `Windows Boot Manager` entries point at **different disks**.
- **Disable Windows Fast Startup** before installing (Power Options) to avoid locked FS / boot-order weirdness.
- `E:` (BootD) on the 1.8 TB disk holds `pagefile.sys`/`hiberfil.sys`/`swapfile.sys` and an old Windows — it's NOT the active boot (active boot is on the SSD), but do not wipe it as part of this project; it's on a disk we're leaving alone.
- 2016 AMI firmware may lack an adjustable boot-menu timeout; the F8 one-time menu still covers rare Windows boots, so not a blocker.
- Windows is never written to by the install → worst case is a fixable boot-order/entry issue (`bcdboot C:\Windows`), not data loss.

## 7. The procedure (summary — full version in the artifact / see below)

**Phase 0 — Prep in Windows**
- Confirm D: has everything from G:. Disable Fast Startup. Create Proxmox USB with Rufus (GPT / UEFI target, DD mode). Download latest Proxmox VE ISO from proxmox.com.

**Phase 1 — Clear Disk 2 (elevated PowerShell)**
```powershell
# 1. Verify the serial maps to Disk 2:
Get-Disk | Where-Object SerialNumber -match 'W502PDPF' | Select-Object Number,FriendlyName,SerialNumber
# Must say Number : 2. If not, STOP.

# 2. Wipe Disk 2 only:
Clear-Disk -Number 2 -RemoveData -RemoveOEM -Confirm:$true

# 3. Verify empty:
Get-Disk 2 | Select-Object Number,PartitionStyle,@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}}
Get-Partition -DiskNumber 2 -ErrorAction SilentlyContinue
```

**Phase 2 — Boot installer:** F8 → choose **UEFI: <USB>** entry → "Install Proxmox VE (graphical)".

**Phase 3 — Target selection (critical):** Target Harddisk → Options → pick the **2.8 TB / W502PDPF** disk. Filesystem **ext4**. Advanced: `hdsize` full, `swapsize` 8, `maxroot` 60.

**Phase 4 — Config:** root password + email; network (static IP recommended); hostname e.g. `pve.home.arpa`. Re-verify target disk on summary. Install. Remove USB on reboot.

**Phase 5 — Boot order (UEFI setup, Del):** Boot tab → #1 = **proxmox**, #2 = **Windows Boot Manager**; set menu timeout ~5 s if available. Save (F10). Test: default boots Proxmox (`https://<ip>:8006`); F8 → Windows Boot Manager boots Windows.

**Phase 6 — Post-install checks (Proxmox shell):**
```
efibootmgr -v          # two entries, different disks' ESPs
lsblk                  # 2.8 TB disk with ESP + LVM pve (root/swap/data)
pvs; vgs; lvs
lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL   # SSD + 1.8 TB NTFS intact, unmounted
```
Then switch to `pve-no-subscription` repo, disable enterprise repo, `apt update && apt dist-upgrade`.

**Recovery:** Windows boot repair if its entry disappears: boot Windows USB → `bcdboot C:\Windows`. To undo Proxmox: delete Disk 2 partitions in Windows Disk Mgmt, remove stale `proxmox` UEFI entry (`efibootmgr -b <n> -B`).

## 8. How the next Kiro should operate

- The user will be driving the physical machine from **another device**; this workspace chat is the assistant channel.
- Confirm current state at session start (don't assume): re-run the Disk 2 identity / partition check before any wipe, since time has passed.
- Keep destructive steps gated behind explicit user confirmation; always verify target disk by **serial W502PDPF** before `Clear-Disk`.
- Respect the already-made decisions in §3 unless the user changes them.

