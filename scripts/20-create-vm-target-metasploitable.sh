#!/usr/bin/env bash
# Run on the Proxmox host (root@192.168.0.8).
#
# Creates VM 110 "target-metasploitable": Metasploitable 2, lab-net only
# (vmbr1, no LAN NIC — this VM must never touch vmbr0).
#
# Gotcha already hit once (see catchup.md section 5): the imported VMDK
# cannot boot from virtio-scsi — the 2012-era kernel drops to (initramfs).
# It must be attached as IDE. This script does that from the start.
#
# Requires the Metasploitable2 VMDK staged at the path below (adjust if
# yours differs — see /var/lib/vz/images-import/).
set -euo pipefail

VMID=110
VMDK=/var/lib/vz/images-import/Metasploitable2-Linux/Metasploitable.vmdk

if qm status "$VMID" &>/dev/null; then
  echo "VM $VMID already exists. Aborting (this script does not clobber existing VMs)."
  exit 1
fi

if [[ ! -f "$VMDK" ]]; then
  echo "Expected VMDK not found at $VMDK"
  echo "Unzip the Metasploitable2 archive in /var/lib/vz/images-import/ first,"
  echo "then adjust the VMDK path in this script if the filename differs."
  exit 1
fi

qm create "$VMID" \
  --name target-metasploitable \
  --ostype l26 \
  --cores 1 \
  --memory 1024 \
  --net0 e1000,bridge=vmbr1 \
  --scsihw virtio-scsi-pci \
  --tags lab,target,metasploitable

qm importdisk "$VMID" "$VMDK" local-lvm
qm set "$VMID" --ide0 local-lvm:vm-"$VMID"-disk-0,size=8G
qm set "$VMID" --boot order=ide0

echo "VM $VMID (target-metasploitable) created."
echo "Start with: qm start $VMID"
echo "It will pick up a DHCP lease from the defender's dnsmasq; the static"
echo "lease for this VM's MAC pins it to 10.10.10.11 (see 11-provision-defender.sh)."
echo "Default creds on first boot: msfadmin/msfadmin (console only, via web UI)."
