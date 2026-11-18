# Lab build scripts

These scripts reproduce the proxmox-lab environment on the `pve` host from
scratch. They capture what was previously built by hand (see `catchup.md`
section 1 for history).

**Scope:** these scripts cover only the resources this project owns and
documents — the isolated lab bridge, the defender, and the three lab targets
(Metasploitable, Juice Shop, symfonos:1). Any other VM on the host (e.g. a
higher-numbered VM you created yourself) is out of scope and these scripts
never touch it.

## Run order

All scripts are run **on the Proxmox host** (`ssh root@192.168.0.8`), except
`11-provision-defender.sh` which runs **on the defender** itself
(`ssh labadmin@192.168.0.212`).

```bash
./00-create-bridge-vmbr1.sh          # isolated lab bridge (idempotent)
./10-create-vm-defender.sh           # VM 100 — Suricata/EveBox/dnsmasq sensor
# ... boot VM 100, then from the defender:
./11-provision-defender.sh           # installs & configures suricata/evebox/dnsmasq
./20-create-vm-target-metasploitable.sh
./22-create-vm-target-juiceshop.sh   # + manual Docker/Juice Shop step, see script header
./23-create-vm-target-symfonos1.sh
```

## Conventions

- Lab subnet: `10.10.10.0/24` on `vmbr1`, no gateway, no DNS — see
  `../docs/architecture.md` for why.
- Static lab IPs are assigned by MAC in dnsmasq (`dhcp-host=`) for anything
  below `.100`; the dynamic pool is `.100`-`.199`.
- VM IDs used by this project: 100 (defender), 110/120/130 (targets).
  140+ is reserved for things outside this project's scope.
- Scripts are **not fully idempotent push-button** — they are a readable,
  re-runnable record of the exact commands used. Re-running a VM-creation
  script against an existing VMID will fail loudly (by design) rather than
  silently clobber a running lab VM. Check `qm list` first.
- No secrets are embedded. SSH keys are read from the defender's own
  cloud-init config at script run time (`qm config 100 | grep sshkeys`), not
  hardcoded.
