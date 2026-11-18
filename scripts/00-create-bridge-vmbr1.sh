#!/usr/bin/env bash
# Run on the Proxmox host (root@192.168.0.8).
#
# Creates the isolated lab bridge vmbr1: no physical port, no address, no
# gateway. This is the containment boundary for the whole lab — see
# docs/architecture.md section "Why it is contained".
#
# This script edits /etc/network/interfaces. It backs up the file first and
# is safe to re-run (it skips if vmbr1 already exists), but a mistake in this
# file can affect vmbr0 too (the management link), so review the diff before
# applying on a host you can't easily get console access to.
set -euo pipefail

IFACE_FILE=/etc/network/interfaces

if grep -q "^iface vmbr1 " "$IFACE_FILE" 2>/dev/null; then
  echo "vmbr1 already defined in $IFACE_FILE — nothing to do."
  exit 0
fi

BACKUP="${IFACE_FILE}.bak-$(date +%Y%m%d-%H%M%S)"
cp "$IFACE_FILE" "$BACKUP"
echo "Backed up $IFACE_FILE to $BACKUP"

cat >> "$IFACE_FILE" <<'EOF'

auto vmbr1
iface vmbr1 inet manual
	bridge-ports none
	bridge-stp off
	bridge-fd 0
#LAB-NET isolated — no uplink, no gateway (10.10.10.0/24 used inside VMs)
EOF

echo "Added vmbr1 to $IFACE_FILE. Review it, then apply with:"
echo "  ifreload -a        # if ifupdown2 is installed"
echo "  systemctl restart networking   # otherwise (will blip vmbr0 briefly)"
echo "Verify afterwards with: ip link show vmbr1"
