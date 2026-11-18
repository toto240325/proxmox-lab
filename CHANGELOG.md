# Changelog

## 0.2.0 — 2026-11-18

- Added scan/recon detection to Suricata (`scripts/suricata/local.rules`) —
  ET Open has no generic port-scan preprocessor, so this closes that gap
  (SYN/NULL/FIN/Xmas/ACK scan, UDP sweep, Nmap NSE UA, slow-scan threshold).
- Verified exploit traffic against Metasploitable (vsftpd 2.3.4 backdoor,
  confirmed root shell); documented the detection gap it revealed.
- Added two new lab targets: OWASP Juice Shop (`target-juiceshop`,
  10.10.10.21:3000) and VulnHub symfonos:1 (`target-symfonos1`, 10.10.10.31).
- Made the lab reproducible: added `scripts/` covering bridge creation,
  defender creation + provisioning (Suricata/EveBox/dnsmasq), and all target
  VM creation.
- Pinned the defender's LAN IP via a router-side DHCP reservation.
- Proxmox host maintenance: switched to the `pve-no-subscription` repository,
  disabled the enterprise and Ceph enterprise repos, ran `apt dist-upgrade`
  (213 packages, kernel bump to `7.0.14-29-pve`, `pve-manager` 9.2.28),
  rebooted onto the new kernel, and took baseline snapshots of all
  project-owned VMs.
- Updated `docs/architecture.md` and `catchup.md` to reflect current state.

## 0.1.0 — 2026-11-17

- Initial project setup
