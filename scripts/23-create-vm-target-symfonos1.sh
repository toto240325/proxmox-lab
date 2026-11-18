#!/usr/bin/env bash
# Run on the Proxmox host (root@192.168.0.8).
#
# Creates VM 130 "target-symfonos1": the VulnHub "symfonos: 1" boot2root VM
# (beginner level — SMB/web enumeration, realistic privesc chain, a useful
# complement to Metasploitable's pre-planted backdoors). Lab-net only.
#
# Download (manual, not automated here — verify the host/mirror yourself):
#   curl -L -o symfonos1.7z https://download.vulnhub.com/symfonos/symfonos1.7z
#   7z x symfonos1.7z -osymfonos1
# (requires p7zip-full: apt-get install -y p7zip-full)
#
# Boots fine from virtio-scsi (unlike Metasploitable — this image is a
# newer vmx-15 VMware hardware version), so no IDE workaround is needed.
set -euo pipefail

VMID=130
VMDK=/var/lib/vz/images-import/symfonos1/symfonos/symfonos-disk1.vmdk

if qm status "$VMID" &>/dev/null; then
  echo "VM $VMID already exists. Aborting (this script does not clobber existing VMs)."
  exit 1
fi

if [[ ! -f "$VMDK" ]]; then
  echo "Expected VMDK not found at $VMDK. Download and extract symfonos1.7z first"
  echo "(see this script's header for the exact steps)."
  exit 1
fi

qm create "$VMID" \
  --name target-symfonos1 \
  --ostype l26 \
  --cores 1 \
  --memory 1024 \
  --net0 e1000,bridge=vmbr1 \
  --scsihw virtio-scsi-pci \
  --tags lab,target,vulnhub,symfonos

qm importdisk "$VMID" "$VMDK" local-lvm
qm set "$VMID" --scsi0 local-lvm:vm-"$VMID"-disk-0,discard=on
qm set "$VMID" --boot order=scsi0

echo "VM $VMID (target-symfonos1) created."
echo "Start with: qm start $VMID"
echo "It will pick up a DHCP lease; the static lease for this VM's MAC pins"
echo "it to 10.10.10.31 (see 11-provision-defender.sh / dnsmasq lab.conf)."
