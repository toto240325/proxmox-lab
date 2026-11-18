#!/usr/bin/env bash
# Run on the Proxmox host (root@192.168.0.8).
#
# Creates VM 100 "defender": the dual-homed Debian 12 sensor that will run
# Suricata, EveBox, and dnsmasq (installed separately by
# 11-provision-defender.sh). eth0 sits on the isolated lab bridge as the IDS
# sniffing interface; eth1 sits on the LAN for management and package
# installs.
#
# Requires a Debian 12 genericcloud qcow2 staged at the path below (adjust
# IMPORT_IMG if yours differs — see /var/lib/vz/images-import/).
set -euo pipefail

VMID=100
IMPORT_IMG=/var/lib/vz/images-import/debian12-cloud.qcow2
SSH_PUBKEY_FILE="${1:-}"   # pass a path to a pubkeys file, or edit inline below

if qm status "$VMID" &>/dev/null; then
  echo "VM $VMID already exists. Aborting (this script does not clobber existing VMs)."
  exit 1
fi

if [[ -z "$SSH_PUBKEY_FILE" ]]; then
  echo "Usage: $0 <path-to-authorized-ssh-pubkeys-file>"
  echo "(no keys hardcoded here — pass the file you want cloud-init to install)"
  exit 1
fi

qm create "$VMID" \
  --name defender \
  --ostype l26 \
  --cores 2 \
  --memory 4096 \
  --net0 virtio,bridge=vmbr1 \
  --net1 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci \
  --serial0 socket \
  --vga serial0 \
  --tags lab,defender,sensor

qm importdisk "$VMID" "$IMPORT_IMG" local-lvm
qm set "$VMID" --scsi0 local-lvm:vm-"$VMID"-disk-0,size=40G
qm set "$VMID" --ide2 local-lvm:cloudinit
qm set "$VMID" --boot order=scsi0
qm set "$VMID" \
  --ciuser labadmin \
  --sshkeys "$SSH_PUBKEY_FILE" \
  --ipconfig0 ip=10.10.10.5/24 \
  --ipconfig1 ip=dhcp \
  --nameserver 1.1.1.1

echo "VM $VMID (defender) created. Start it with: qm start $VMID"
echo "Lab IP will be 10.10.10.5 (no gateway). LAN IP comes from DHCP on vmbr0."
echo "Next: boot it, then run 11-provision-defender.sh on the VM itself."
