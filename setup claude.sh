#!/bin/bash

#############################################
# Script d'installation de claude-ansible
# À exécuter en tant que root sur la VM
#############################################

# CONFIGURATION : Insérez votre clé publique SSH ici
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMf+uB3rsislTic+79tb+d5g+T4C2WUAcWL+LVRHr5v claude-mcp-restricted"

set -e  # Arrête le script en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Installation de l'environnement claude-ansible ===${NC}\n"

# 1. Création de l'utilisateur
echo -e "${YELLOW}[1/6] Création de l'utilisateur claude-ansible...${NC}"
if id "claude-ansible" &>/dev/null; then
    echo "L'utilisateur claude-ansible existe déjà"
else
    useradd -m -s /bin/bash claude-ansible
    echo -e "${GREEN}✓ Utilisateur créé${NC}"
fi

# 2. Installation d'Ansible dans un venv dédié
echo -e "\n${YELLOW}[2/6] Installation d'Ansible dans le venv...${NC}"
if [ -d "/home/claude-ansible/venv-ansible" ]; then
    echo "Le venv existe déjà, suppression et recréation..."
    rm -rf /home/claude-ansible/venv-ansible
fi

su - claude-ansible -c "python3 -m venv /home/claude-ansible/venv-ansible"
su - claude-ansible -c "source /home/claude-ansible/venv-ansible/bin/activate && pip install --upgrade pip"
su - claude-ansible -c "source /home/claude-ansible/venv-ansible/bin/activate && pip install ansible 'pywinrm[credssp]' requests-ntlm"
echo -e "${GREEN}✓ Ansible installé${NC}"

# 3. Création du script de restriction
echo -e "\n${YELLOW}[3/6] Création du script de restriction...${NC}"
cat > /usr/local/bin/claude-playbook.sh << 'EOFSCRIPT'
#!/bin/bash

# Activation du venv Ansible
source /home/claude-ansible/venv-ansible/bin/activate

# Lire la commande depuis SSH_ORIGINAL_COMMAND avec preservation des guillemets
eval "set -- $SSH_ORIGINAL_COMMAND"

ACTION="$1"
shift

case "$ACTION" in
    list)
        ls /Infra_GSBV2/Ansible/playbooks/
        ;;
    show)
        PLAYBOOK="$1"
        if [[ -f "/Infra_GSBV2/Ansible/playbooks/${PLAYBOOK}.yml" ]]; then
            cat "/Infra_GSBV2/Ansible/playbooks/${PLAYBOOK}.yml"
        else
            echo "Playbook introuvable"
            exit 1
        fi
        ;;
    run)
        PLAYBOOK="$1"
        shift
        if [[ -f "/Infra_GSBV2/Ansible/playbooks/${PLAYBOOK}.yml" ]]; then
            cd /Infra_GSBV2/Ansible
            # Passer tous les arguments directement a ansible-playbook
            exec sudo /home/claude-ansible/venv-ansible/bin/ansible-playbook \
                "playbooks/${PLAYBOOK}.yml" "$@"
        else
            echo "Playbook introuvable"
            exit 1
        fi
        ;;
    *)
        echo "Usage: list | show <playbook> | run <playbook> [-e 'vars']"
        exit 1
        ;;
esac
EOFSCRIPT

chmod 777 /usr/local/bin/claude-playbook.sh
echo -e "${GREEN}✓ Script créé: /usr/local/bin/claude-playbook.sh${NC}"

# 4. Configuration sudoers pour permettre l'exécution d'Ansible
echo -e "\n${YELLOW}[4/6] Configuration sudoers...${NC}"
cat > /etc/sudoers.d/claude-ansible << 'EOFSUDO'
# Permet à claude-ansible d'exécuter ansible-playbook sans mot de passe
claude-ansible ALL=(ALL) NOPASSWD: /home/claude-ansible/venv-ansible/bin/ansible-playbook
EOFSUDO

chmod 440 /etc/sudoers.d/claude-ansible
echo -e "${GREEN}✓ Configuration sudoers ajoutée${NC}"

# 5. Configuration SSH
echo -e "\n${YELLOW}[5/6] Configuration SSH...${NC}"

# Vérifier si la configuration existe déjà
if grep -q "Match User claude-ansible" /etc/ssh/sshd_config; then
    echo "La configuration SSH existe déjà"
else
    cat >> /etc/ssh/sshd_config << 'EOFSSH'

# Restriction pour Claude MCP
Match User claude-ansible
    ForceCommand /usr/local/bin/claude-playbook.sh
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
EOFSSH
    echo -e "${GREEN}✓ Configuration SSH ajoutée${NC}"
fi

# Vérification de la configuration SSH
echo -e "\n${YELLOW}Vérification de la configuration SSH...${NC}"
if sshd -t; then
    echo -e "${GREEN}✓ Configuration SSH valide${NC}"
    systemctl restart sshd
    echo -e "${GREEN}✓ Service SSH redémarré${NC}"
else
    echo -e "${RED}✗ Erreur dans la configuration SSH${NC}"
    exit 1
fi

# 6. Configuration de la clé SSH publique
echo -e "\n${YELLOW}[6/6] Configuration de la clé SSH publique...${NC}"
if [ -z "$SSH_PUBLIC_KEY" ]; then
    echo -e "${RED}✗ ERREUR: SSH_PUBLIC_KEY est vide${NC}"
    echo -e "${YELLOW}Veuillez éditer le script et renseigner votre clé publique dans la variable SSH_PUBLIC_KEY${NC}"
    exit 1
fi

mkdir -p /home/claude-ansible/.ssh
echo "$SSH_PUBLIC_KEY" > /home/claude-ansible/.ssh/authorized_keys
chmod 700 /home/claude-ansible/.ssh
chmod 600 /home/claude-ansible/.ssh/authorized_keys
chown -R claude-ansible:claude-ansible /home/claude-ansible/.ssh
echo -e "${GREEN}✓ Clé SSH publique installée${NC}"

# Résumé
echo -e "\n${GREEN}==================================${NC}"
echo -e "${GREEN}✓ Installation terminée avec succès${NC}"
echo -e "${GREEN}==================================${NC}"
