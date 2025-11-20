#!/bin/bash

set -e

# === CONFIG ===
CTID=110
CT_LIST=(110 113 114 115)
VM_LIST=(201 202)
CTNAME="terransible"
HOSTNAME="terransible"
IP="172.16.0.15"
IP_SETUP="$IP/24"
GW="172.16.0.254"
BRIDGE="vmbr0"
SSH_KEY_PATH="/root/.ssh/terransible"
LXC_TEMPLATE_FILENAME="debian-12-standard_12.7-1_amd64.tar.zst"
LXC_TEMPLATE="/var/lib/vz/template/cache/$LXC_TEMPLATE_FILENAME"
LXC_TEMPLATE_URL="http://download.proxmox.com/images/system/$LXC_TEMPLATE_FILENAME"
CHEMIN_TEMPLATE="local:vztmpl/$LXC_TEMPLATE_FILENAME"
CONTAINER_SSH_PORT=22
node=$(hostname)
PM_API="https://172.16.0.253:8006/api2/json"
TOKEN_USER="terraform-prov@pam"
TOKEN_NAME="auto-token"
USER_ROLE="Administrator"
GITHUB_REPO="https://github.com/LeQ-letigre/Infra_GSBV2.git"


# 0.5 Téléchgement des templates OpnSenses

if [ ! -f /var/lib/vz/dump/opnsense-master.vma.zst ]; then
  wget --no-check-certificate -O /var/lib/vz/dump/opnsense-master.vma.zst https://m2shelper.boisloret.fr/scripts/deploy-infra-gsb/opnsense-master.vma.zst
fi

if [ ! -f /var/lib/vz/dump/opnsense-backup.vma.zst ]; then
  wget --no-check-certificate -O /var/lib/vz/dump/opnsense-backup.vma.zst https://m2shelper.boisloret.fr/scripts/deploy-infra-gsb/opnsense-backup.vma.zst
fi

if qm status 2100 &>/dev/null; then
    qm destroy 2100 --purge
fi

if pct status 2101 &>/dev/null; then
    pct destroy 2101
fi

# 2) Restaurer les OpnSenses
qmrestore /var/lib/vz/dump/opnsense-master.vma.zst  2100 --storage local-lvm --unique 1
qm set 2100 --name "OpnSense-Master-Template"

# 3) Marquer en template
qm template 2100

# 2) Restaurer les OpnSenses
qmrestore /var/lib/vz/dump/opnsense-backup.vma.zst  2101 --storage local-lvm --unique 1
qm set 2101 --name "OpnSense-Backup-Template"
 
# 3) Marquer en template
qm template 2101


# 1) Télécharger la backup du win srv 2022
if [ ! -f /var/lib/vz/dump/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst ]; then
  wget --no-check-certificate -O /var/lib/vz/dump/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst https://m2shelper.boisloret.fr/scripts/deploy-infra-gsb/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst
fi
if [ ! -f /var/lib/vz/dump/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst.notes ]; then
  wget --no-check-certificate -O /var/lib/vz/dump/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst.notes https://m2shelper.boisloret.fr/scripts/deploy-infra-gsb/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst.notes
fi
 
if qm status 2000 &>/dev/null; then
    qm destroy 2000 --purge
fi

if pct status 2000 &>/dev/null; then
    pct destroy 2000
fi
 
# 2) Restaurer sur le stockage voulu (ex: local-lvm) et VMID fixe (ex: 2000)
qmrestore /var/lib/vz/dump/vzdump-qemu-101-2025_09_13-14_41_02.vma.zst  2000 --storage local-lvm --unique 1
qm set 2000 --name "WinTemplate"
 
# 3) Marquer en template
qm template 2000

# === 0. Prérequis ===
echo "[+] Vérification/installation de jq..."
if ! command -v jq >/dev/null 2>&1; then
  apt update && apt install -y jq
fi

echo "[+] Vérification et suppression des conteneurs LXC si présents..."
for CT in "${CT_LIST[@]}"; do
  if pct status "$CT" &>/dev/null; then
    echo "⚠️ Conteneur $CT détecté. Suppression..."
    pct stop "$CT" 2>/dev/null || true
    pct destroy "$CT"
  fi
done

echo "[+] Vérification et suppression des VMs si présentes..."
for VM in "${VM_LIST[@]}"; do
  if qm status "$VM" &>/dev/null; then
    echo "⚠️ VM $VM détectée. Suppression..."
    qm stop "$VM" 2>/dev/null || true
    qm destroy "$VM" --purge
  fi
done

# === 1. Télécharger l'ISO LXC ===
# Lxc Debian 12
echo "[+] Vérification de l'image Debian 12 LXC..."
if [ ! -f "$LXC_TEMPLATE" ]; then
  echo "[+] Téléchargement de l'image LXC $LXC_TEMPLATE_FILENAME..."
  wget -O "$LXC_TEMPLATE" "$LXC_TEMPLATE_URL"
fi

# === 2. Génération de la paire de clés SSH ===
echo "[+] Génération de la paire de clés SSH pour le conteneur..."
if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
fi

PUB_KEY=$(cat "${SSH_KEY_PATH}.pub")

# === 3. Création du conteneur LXC ===
if pct status 110 &>/dev/null; then
  echo "[!] Le conteneur 110 existe déjà. Destruction en cours..."
  pct stop 110
  pct destroy 110
fi

echo "[+] Création du conteneur LXC '$CTNAME' avec IP $IP_SETUP..."
pct destroy $CTID 2>/dev/null || true

pct create $CTID "$LXC_TEMPLATE" \
  -hostname $HOSTNAME \
  -cores 4 \
  -memory 4096 \
  -net0 name=eth0,bridge=$BRIDGE,ip=$IP_SETUP,gw=$GW \
  -storage local-lvm \
  -rootfs local-lvm:8 \
  -features nesting=1 \
  -password Formation13@ \
  -unprivileged 0
echo "[+] Démarrage du conteneur..."
pct start $CTID

# 3.5 Création des bridges Linuxs 
cat >> /etc/network/interfaces <<'EOF'

auto vmbr2
iface vmbr2 inet static
        address 10.10.0.6/28
        bridge-ports eno2
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

auto Sync
iface Sync inet manual
        bridge-ports none
        bridge-stp off
        bridge-fd 0
EOF

echo "[+] Bridges vmbr2 et Sync configurés dans /etc/network/interfaces."
ifreload -a
echo "[+] Interfaces rechargées."


# === 4. Attente que le conteneur soit up ===
echo "[+] Attente du démarrage du conteneur..."
while ! ping -c 1 -W 1 "$IP" > /dev/null 2>&1; do
    sleep 1
done

# === 5. Injection de la clé SSH ===
echo "[+] Injection de la clé SSH dans le conteneur..."
pct exec $CTID -- mkdir -p /root/.ssh
pct exec $CTID -- bash -c "echo '$PUB_KEY' > /root/.ssh/authorized_keys"
pct exec $CTID -- chmod 600 /root/.ssh/authorized_keys

# === 6. Authentification Proxmox et création du token ===
echo "[+] Création du token Terraform sur Proxmox..."

if pveum user list | grep -q "$TOKEN_USER"; then
  echo "[!] L'utilisateur $TOKEN_USER existe déjà. Suppression en cours..."
  pveum user delete "$TOKEN_USER"
fi

echo "[+] Vérification/création de l'utilisateur $TOKEN_USER"
pveum user list | grep -q "^$TOKEN_USER" || {
  pveum user add "$TOKEN_USER"
  echo "[+] Utilisateur $TOKEN_USER créé."
}

echo "[+] Attribution du rôle $USER_ROLE à $TOKEN_USER sur /"
pveum acl modify / -user "$TOKEN_USER" -role "$USER_ROLE"

echo "[+] Création du token $TOKEN_NAME..."
TOKEN_OUTPUT=$(pveum user token add "$TOKEN_USER" "$TOKEN_NAME" --privsep 0 --output-format json 2>/dev/null)

if [ -z "$TOKEN_OUTPUT" ]; then
  echo "[!] Le token existe probablement déjà. Supprime-le avec :"
  echo "    pveum user token delete \"$TOKEN_USER\" \"$TOKEN_NAME\""
  exit 1
fi

export TF_TOKEN_ID="$TOKEN_USER!$TOKEN_NAME"
export TF_TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | jq -r '.value')

echo ""
echo "Token créé avec succès :"
echo "TF_TOKEN_ID     = $TF_TOKEN_ID"
echo "TF_TOKEN_SECRET = $TF_TOKEN_SECRET"

# === 8. Connexion au conteneur pour setup ===
echo "[+] Connexion au conteneur pour déploiement Terraform + Ansible..."
rm -f ~/.ssh/known_hosts

IP_ADDR="${IP%%/*}"

echo "[+] Vérification que le conteneur est bien en ligne..."
until ping -c1 -W1 "$IP_ADDR" >/dev/null 2>&1; do
  echo "⏳ En attente que $IP_ADDR soit en ligne..."
  sleep 2
done

ssh -T -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" root@"$IP" <<EOF

#!/bin/bash
set -e

DISTRO="bookworm"
GITHUB_REPO="$GITHUB_REPO"
node="$node"

echo "🔧 Mise à jour des paquets..."
apt update && apt upgrade -y

echo "📦 Installation des outils de base..."
apt install -y sudo curl wget gnupg lsb-release software-properties-common unzip python3 python3-pip python3-venv git locales

echo "🌍 Correction des locales pour éviter les erreurs de type 'setlocale'..."
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "🐍 Création d’un venv global pour Ansible (Linux + Windows)..."
mkdir -p ~/venvs
python3 -m venv ~/venvs/ansible

echo "📦 Activation du venv et installation des dépendances Ansible + WinRM..."
source ~/venvs/ansible/bin/activate
pip install --upgrade pip
pip install ansible "pywinrm[credssp]" requests-ntlm

echo "🔗 Ajout d’un alias global dans ~/.bashrc pour ansible et ansible-playbook"
if ! grep -q "venvs/ansible" ~/.bashrc; then
  echo 'ansible() { source ~/venvs/ansible/bin/activate && command ansible "\$@"; }' >> ~/.bashrc
  echo 'ansile-playbook() { source ~/venvs/ansible/bin/activate && command ansible-playbook "\$@"; }' >> ~/.bashrc
fi

wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" > /etc/apt/sources.list.d/hashicorp.list
apt update
apt install -y terraform

echo "[✔] Vérification de l'installation de Terraform..."
command -v terraform >/dev/null || { echo "❌ Terraform n’est pas installé correctement"; exit 1; }

echo "✅ VM terransible prête : Ansible, Terraform, Locales, Git et Alias configurés."

echo "[+] Clonage du dépôt Git..."
git clone "\$GITHUB_REPO" /Infra_GSBV2 || { echo "❌ Clone Git échoué"; exit 1; }

echo "[+] Écriture du fichier secrets.auto.tfvars..."
cat <<EOT > /Infra_GSBV2/Terraform/secrets.auto.tfvars
proxmox_api_url         = "$PM_API"
proxmox_api_token_id    = "$TOKEN_USER!$TOKEN_NAME"
proxmox_api_token       = "$TF_TOKEN_SECRET"
target_node             = "$node"
chemin_cttemplate       = "$CHEMIN_TEMPLATE"
EOT

cd /Infra_GSBV2/Terraform
terraform init
terraform apply -auto-approve

echo "[+] Attente que les machines 172.16.0.2 et 172.16.0.1 soient en ligne..."
while ! ping -c 1 -W 1 172.16.0.2 > /dev/null 2>&1; do sleep 1; done
while ! ping -c 1 -W 1 172.16.0.1 > /dev/null 2>&1; do sleep 1; done

cd ../Ansible
ansible-galaxy install -r requirements.yml
ansible-playbook Install_InfraGSB.yml

EOF

echo "✅ Déploiement complet terminé avec succès."
