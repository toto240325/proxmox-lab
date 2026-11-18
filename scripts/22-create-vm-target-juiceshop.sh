#!/usr/bin/env bash
# Run on the Proxmox host (root@192.168.0.8).
#
# Creates VM 120 "target-juiceshop": a Debian 12 cloud VM, lab-net only,
# intended to run the official OWASP Juice Shop Docker image.
#
# Juice Shop itself is NOT installed by this script — see the manual step
# below. The lab net has no gateway/DNS by design (containment boundary),
# so the VM cannot apt/docker-pull directly. The documented approach is to
# temporarily hot-add a second NIC on vmbr0 for provisioning only, then
# remove it:
#
#   qm set 120 --net1 virtio,bridge=vmbr0 --ipconfig1 ip=dhcp
#   qm reboot 120
#   ssh -J labadmin@<defender-lan-ip> labadmin@10.10.10.21
#     sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg
#     sudo install -m 0755 -d /etc/apt/keyrings
#     curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#     echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list
#     sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
#     sudo docker pull bkimminich/juice-shop
#     sudo docker run -d --name juice-shop --restart unless-stopped -p 3000:3000 bkimminich/juice-shop
#   # then back on the host, remove the temporary NIC:
#   qm set 120 --delete net1,ipconfig1
#   qm reboot 120
#
# Requires a Debian 12 genericcloud qcow2 staged at the path below.
set -euo pipefail

VMID=120
IMPORT_IMG=/var/lib/vz/images-import/debian12-cloud.qcow2
SSH_PUBKEY_FILE="${1:-}"

if qm status "$VMID" &>/dev/null; then
  echo "VM $VMID already exists. Aborting (this script does not clobber existing VMs)."
  exit 1
fi

if [[ -z "$SSH_PUBKEY_FILE" ]]; then
  echo "Usage: $0 <path-to-authorized-ssh-pubkeys-file>"
  exit 1
fi

qm create "$VMID" \
  --name target-juiceshop \
  --ostype l26 \
  --cores 2 \
  --memory 2048 \
  --cpu host \
  --sockets 1 \
  --net0 virtio,bridge=vmbr1 \
  --scsihw virtio-scsi-pci \
  --serial0 socket \
  --vga serial0 \
  --tags lab,target,juiceshop

qm importdisk "$VMID" "$IMPORT_IMG" local-lvm
qm set "$VMID" --scsi0 local-lvm:vm-"$VMID"-disk-0,discard=on,ssd=1
qm disk resize "$VMID" scsi0 16G
qm set "$VMID" --ide2 local-lvm:cloudinit
qm set "$VMID" --boot order=scsi0
qm set "$VMID" \
  --ciuser labadmin \
  --sshkeys "$SSH_PUBKEY_FILE" \
  --ipconfig0 ip=10.10.10.21/24 \
  --nameserver 1.1.1.1

echo "VM $VMID (target-juiceshop) created at 10.10.10.21 (no gateway)."
echo "Start with: qm start $VMID"
echo "Then follow the manual Docker/Juice Shop steps in this script's header."
echo "App will listen on :3000 once deployed."
