#!/usr/bin/env bash
# Run on the DEFENDER itself (labadmin@192.168.0.212), with sudo.
#
# Installs and configures Suricata (IDS), EveBox (alert UI), and dnsmasq
# (lab DHCP) to match the documented lab setup. See docs/architecture.md and
# catchup.md section 5 ("Gotchas already solved") for why each step exists.
set -euo pipefail

LAB_IFACE=eth0        # sniffing / lab-net interface
LAB_NET="10.10.10.0/24"
TARGET_MAC="BC:24:11:59:AC:75"   # Metasploitable net0 MAC -> static lease .11

echo "=== 1. Suricata (from bookworm-backports — plain 'apt install suricata' fails on Debian 12) ==="
sudo apt-get update -qq
sudo apt-get install -y -t bookworm-backports suricata

echo "=== 2. HOME_NET and af-packet interface ==="
sudo sed -i "s/^\( *\)HOME_NET:.*/\1HOME_NET: \"[${LAB_NET}]\"/" /etc/suricata/suricata.yaml
sudo sed -i "0,/interface: eth0/{s/interface: eth0/interface: ${LAB_IFACE}/}" /etc/suricata/suricata.yaml

echo "=== 3. local.rules — scan/recon detection ==="
echo "    ET Open has no generic port-scan preprocessor (unlike Snort's sfPortscan)."
echo "    This file closes that gap for the lab. See ../docs/architecture.md section 5."
sudo cp "$(dirname "$0")/suricata/local.rules" /var/lib/suricata/rules/local.rules
sudo sed -i '/^rule-files:/a\  - local.rules' /etc/suricata/suricata.yaml
sudo sed -i 's|^# threshold-file: /etc/suricata/threshold.config|threshold-file: /etc/suricata/threshold.config|' /etc/suricata/suricata.yaml

sudo suricata -T -c /etc/suricata/suricata.yaml -v
sudo systemctl enable --now suricata
sudo systemctl restart suricata

echo "=== 4. EveBox (needs gnupg first — the cloud image doesn't have it) ==="
sudo apt-get install -y gnupg
curl -s https://evebox.org/files/GPG-KEY-evebox | sudo apt-key add - 2>/dev/null || true
echo "deb https://evebox.org/files/debian/ stable main" | sudo tee /etc/apt/sources.list.d/evebox.list >/dev/null
sudo apt-get update -qq
sudo apt-get install -y evebox

sudo tee /etc/evebox/evebox.yaml >/dev/null <<'EOF'
# EveBox lab config — self-contained sqlite, reads Suricata eve.json
http:
  host: "0.0.0.0"
  port: 5636
  tls:
    enabled: false
authentication: false
database:
  type: sqlite
input:
  enabled: true
  paths:
    - "/var/log/suricata/eve.json"
    - "/var/log/suricata/eve.*.json"
EOF
sudo systemctl enable --now evebox
sudo systemctl restart evebox

echo "=== 5. dnsmasq — lab DHCP only, no gateway/DNS handed out ==="
echo "    IMPORTANT: dnsmasq loads every file in /etc/dnsmasq.d/, including"
echo "    backups. Never leave a .bak file in that directory — it will"
echo "    collide with the original and refuse to start. Use a sibling dir."
sudo apt-get install -y dnsmasq
sudo mkdir -p /etc/dnsmasq.d-backups
sudo tee /etc/dnsmasq.d/lab.conf >/dev/null <<EOF
# Lab DHCP — isolated ${LAB_NET}, bound to ${LAB_IFACE} only.
# No gateway (option 3) and no DNS (option 6) advertised => targets stay offline.
interface=${LAB_IFACE}
bind-interfaces
except-interface=eth1
dhcp-range=10.10.10.100,10.10.10.199,255.255.255.0,12h
# static lease for Metasploitable by its NIC MAC -> 10.10.10.11
dhcp-host=${TARGET_MAC},10.10.10.11
# static lease for symfonos:1 (VulnHub) by its NIC MAC -> 10.10.10.31
dhcp-host=BC:24:11:4D:97:B9,10.10.10.31
# explicitly send NO router and NO dns so there is no path off-lab
dhcp-option=3
dhcp-option=6
# do not act as a DNS forwarder
port=0
EOF
sudo systemctl enable --now dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl is-active suricata evebox dnsmasq

echo "=== Done. EveBox: http://<defender-lan-ip>:5636 ==="
