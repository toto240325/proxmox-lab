# Prompts — proxmox-lab

Useful prompts for the kiro agent working on this project.

---

## Initial setup prompt

> I am starting a new project called proxmox-lab. Please read the steering files and check your messages to understand the landscape you are part of. Then help me set up the project structure.

---

## Deploy prompt

> Commit, release, and deploy this change.

---

## Audit prompt

> Check that this project is consistent with the landscape conventions (version file, changelog, branch, deploy scripts).


--------------------------------------------
I have a proxmox cluster that I can access with ssh proxmox and which has this config:

Host — pve (192.168.0.8)
Proxmox VE 9.2.2, kernel 7.0.2-6-pve.

Storage: local-lvm (LVM-thin, ~2.6 TB free), local dir for ISOs/imports.

Bridges: vmbr0 (LAN/mgmt), vmbr1 (isolated lab).

Imported images staged in /var/lib/vz/images-import/.

VM 100 — defender (Debian 12 "bookworm")
4 GB RAM / 2 cores / 40 GB disk. Built from the Debian genericcloud qcow2 + cloud-init.

User labadmin, SSH-key auth (keys: id_ed25519_toto, _toto_local, devlin).

NICs: eth0 10.10.10.5/24 (lab sensor), eth1 192.168.0.212/24 (DHCP, mgmt).

Services:
  - Suricata 7.0.10 — IDS sniffing eth0, HOME_NET 10.10.10.0/24,
    ET Open ruleset (~53k rules), logs to /var/log/suricata/eve.json.
  - EveBox 0.31.0 — web UI on :5636, sqlite backend, tails eve.json.
  - dnsmasq — DHCP for the lab net, bound to eth0 only, hands out
    10.10.10.100-199 + a static lease pinning the target to .11.

VM 110 — target-metasploitable (Metasploitable 2)
1 GB RAM / 1 core / 8 GB disk. Imported VMDK, attached as IDE (ide0)
  — the 2012-era kernel cannot boot from virtio-scsi (it dropped to initramfs
  until switched to IDE).

Single NIC net0 (e1000) on vmbr1, address 10.10.10.11 via DHCP.

Deliberately vulnerable: vsftpd 2.3.4 backdoor, UnrealIRCd, old Samba, bindshell
  on 1524, DVWA/Mutillidae web apps, etc. Default creds msfadmin/msfadmin.

Never place this VM on vmbr0.

I need your help to create on the isolated lan (vmbr1) a new vm (the attacker machine) that will be sized and configured to host our Artex implementation.  Ideally, we should allow a way to access machine 192.168.0.7 on a given port, which is a proxy to a few llm, like this: curl -s http://192.168.0.7:28024/v1/chat/completions   -H "Content-Type: application/json"   -H "X-Hermes-Client: curl-test"   -d '{"messages": [{"role": "user", "content": "What is the diameter of planet mars? Short answer."}]}'

Answer:
Create VM 120 (artex-attacker) with two NICs: net0 on the isolated vmbr1 lab and net1 on vmbr0 solely as a tightly firewalled LLM-proxy uplink. Size it 4 vCPU, 16 GB RAM, 80 GB disk—comfortable for Docker, ARTEX, PostgreSQL, evidence storage, and concurrent agent work, without hosting models locally since your LLM endpoint is remote. Proxmox supports per-interface firewalling and Cloud-Init IP configuration on net[n].

Network design
Interface	Bridge	Address	Purpose	Firewall
net0	vmbr1	10.10.10.20/24, no gateway	ARTEX attack interface; can reach Metasploitable at 10.10.10.11	Off
net1	vmbr0	DHCP or static LAN address	Only path to 192.168.0.7:28024	On
Do not give the attacker VM unrestricted LAN access. The net1 firewall policy should permit outbound TCP to 192.168.0.7:28024 only; deny all other outbound and inbound traffic. Proxmox’s VM firewall is enabled per interface with firewall=1.

Create the VM
From your workstation:

bash
ssh proxmox
First identify the Debian cloud image already staged for import:

bash
ls -lh /var/lib/vz/images-import/
Then create the VM. Adjust the image filename in IMPORT_IMG if yours differs:

bash
VMID=120
IMPORT_IMG=/var/lib/vz/images-import/debian-12-genericcloud-amd64.qcow2

qm create $VMID \
  --name artex-attacker \
  --ostype l26 \
  --cores 4 \
  --memory 16384 \
  --balloon 0 \
  --cpu host \
  --sockets 1 \
  --bios ovmf \
  --machine q35 \
  --agent enabled=1 \
  --net0 virtio,bridge=vmbr1,firewall=0 \
  --net1 virtio,bridge=vmbr0,firewall=1 \
  --scsihw virtio-scsi-pci \
  --serial0 socket \
  --vga serial0 \
  --onboot 1 \
  --tags lab,artex,attacker

qm set $VMID --efidisk0 local-lvm:1,format=raw,efitype=4m,pre-enrolled-keys=0
qm importdisk $VMID "$IMPORT_IMG" local-lvm
qm set $VMID --scsi0 local-lvm:vm-$VMID-disk-0,discard=on,ssd=1
qm disk resize $VMID scsi0 80G
qm set $VMID --ide2 local-lvm:cloudinit
qm set $VMID --boot order=scsi0
efidisk0, UEFI, and the Cloud-Init drive are needed for a normal Debian generic-cloud deployment; Cloud-Init is attached as a virtual CD-ROM in Proxmox.

Configure Cloud-Init
Use the same public key material you already use for labadmin. Export the applicable public key first—for example:

bash
PUBKEY="$(cat ~/.ssh/id_ed25519_toto.pub)"
Then apply it on the Proxmox host:

bash
qm set $VMID \
  --ciuser labadmin \
  --sshkeys "$PUBKEY" \
  --ipconfig0 ip=10.10.10.20/24 \
  --ipconfig1 ip=dhcp \
  --searchdomain lab.local \
  --nameserver 10.10.10.1
Notes:

net0 has no gateway: the attacker must not use the lab network to reach the Internet or the LAN.

net1 uses DHCP for simplicity. If your router reserves addresses, prefer a static reservation such as 192.168.0.213/24; replace ip=dhcp with ip=192.168.0.213/24,gw=192.168.0.1 only after confirming your LAN gateway.

Cloud-Init maps ipconfig0/ipconfig1 to net0/net1.

Start it:

bash
qm start $VMID
qm status $VMID
qm guest cmd $VMID network-get-interfaces
Lock down the uplink
In the Proxmox web UI, go to Datacenter → Firewall, ensure the firewall is enabled, then open VM 120 → Firewall → Rules and create:

Direction	Action	Protocol	Source	Destination	Port	Comment
OUT	ACCEPT	TCP	VM 120	192.168.0.7	28024	LLM proxy only
IN	DROP	ANY	any	VM 120	any	No inbound services
OUT	DROP	ANY	VM 120	any	any	No other egress
The exact outbound ACCEPT rule is the important one; Proxmox’s default firewall policy is drop, but explicit deny rules make the intent auditable. Do not add DNS, NTP, HTTP, HTTPS, or package-mirror rules unless you deliberately need them for a maintenance window.

For package installation, either install Docker while temporarily allowing the required Debian mirrors, or prepare an offline Docker/ARTEX bundle. After installation, remove any temporary egress exceptions.

Deploy ARTEX
SSH into the new VM:

bash
ssh labadmin@10.10.10.20
Install Docker:

bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian bookworm stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker labadmin
newgrp docker
This requires temporary Internet access; perform it before applying the final strict firewall policy, or use a temporary maintenance rule.

Clone and configure ARTEX:

bash
git clone https://github.com/BaaRai/ARTEX.git
cd ARTEX
cp .env.example .env
Set a strong PostgreSQL password and configure the OpenAI-compatible proxy:

dotenv
POSTGRES_PASSWORD=<long-random-password>

OPENAI_API_KEY=<key-required-by-your-proxy-if-any>
OPENAI_BASE_URL=http://192.168.0.7:28024/v1
If the proxy accepts unauthenticated requests, use a non-empty placeholder value for OPENAI_API_KEY if ARTEX requires one, but do not send real credentials unless the proxy expects them.

Start ARTEX:

bash
docker compose up -d --build
docker compose logs -f artex
The UI will listen on 127.0.0.1:8787 inside the VM. Retrieve the setup token with:

bash
docker compose logs artex | grep -i "setup token"
Access the ARTEX UI
Do not expose port 8787 on vmbr0. From your workstation, tunnel through the Proxmox host:

bash
ssh -L 8787:10.10.10.20:8787 proxmox
Then open:

text
http://localhost:8787
This works because the Proxmox host is attached to vmbr1 and can reach the attacker VM’s lab address. It keeps ARTEX’s control plane off the LAN and off the Internet.

Validate the LLM path
From the attacker VM:

bash
curl -s http://192.168.0.7:28024/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "X-Hermes-Client: artex-lab" \
  -d '{"messages":[{"role":"user","content":"What is the diameter of planet Mars? Short answer."}]}'
If this succeeds but ARTEX cannot connect, check that its configured base URL is exactly http://192.168.0.7:28024/v1, that the selected provider profile is OpenAI-compatible, and that the proxy’s expected authentication header/key has been supplied.

First ARTEX task
Configure the first task conservatively:

Target scope: 10.10.10.11 only.

Noise profile: quiet.

Token budget: start around 300,000 tokens and 80 turns.

Approval gates: enabled, especially for Bash and any potentially destructive action.

No external MCP servers, browser-session capture, or credentials from the LAN.

Confirm that Suricata on defender sees the expected traffic and that EveBox displays alerts.

Your isolated design is sound: Metasploitable remains pinned at 10.10.10.11 on vmbr1, the defender observes the lab segment on eth0, and the new attacker VM participates only in that segment while its LAN NIC is restricted to the single LLM-proxy destination.