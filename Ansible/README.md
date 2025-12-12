# Déploiement E6 - Infrastructure GSB

## 🎯 Vue d'ensemble

Ce projet Ansible permet de déployer automatiquement toute l'infrastructure GSB à partir d'un questionnaire interactif.

## 📋 Fichiers principaux

- **`epreuve.yml`** : Playbook interactif de collecte de données
- **`run_all.yml`** : Playbook orchestrateur qui exécute tout automatiquement
- **`playbooks/`** : Playbooks individuels pour chaque composant
- **`vars/generated_vars.yml`** : Fichier généré automatiquement avec toutes les variables

## 🚀 Utilisation

### Option 1 : Déploiement complet automatique (RECOMMANDÉ)

```bash
# Active l'environnement virtuel Python
source ~/venvs/ansible/bin/activate

# Lance le déploiement complet
ansible-playbook Ansible/run_all.yml
```

Cette commande va :
1. Poser toutes les questions interactives
2. Générer le fichier de variables
3. Exécuter automatiquement tous les playbooks dans le bon ordre

### Option 2 : Déploiement en deux étapes

**Étape 1 : Collecte des données**
```bash
ansible-playbook Ansible/epreuve.yml
```

**Étape 2 : Exécution manuelle des playbooks**
```bash
# Tous d'un coup
ansible-playbook Ansible/playbooks/Active_directory.yml
ansible-playbook Ansible/playbooks/dir_create_ad.yml
ansible-playbook Ansible/playbooks/mappage_lecteur.yml
ansible-playbook Ansible/playbooks/blocage_cmd.yml
ansible-playbook Ansible/playbooks/bloquer_domaines_adguard.yml
ansible-playbook Ansible/playbooks/parefeu.yml
ansible-playbook Ansible/playbooks/Vif_dhcp_routeur.yml
ansible-playbook Ansible/playbooks/switchs.yml

# Ou individuellement selon vos besoins
ansible-playbook Ansible/playbooks/switchs.yml
```

## 📝 Questions posées lors du déploiement

### Configuration générale
- Nom de l'OU (Unité d'Organisation)
- Nom du groupe à créer
- Nom du dossier partagé
- Lettre de lecteur pour le mappage
- Blocage du CMD (oui/non)

### Utilisateurs Active Directory
- Nombre d'utilisateurs
- Pour chaque utilisateur : prénom, nom, username, mot de passe

### Domaines à bloquer (AdGuard)
- Nombre de domaines
- Liste des domaines (ex: facebook.com, youtube.com)

### Configuration réseau
- ID de la VIF
- Adresse IP de la VIF
- Plage DHCP (début, fin, passerelle, DNS)
- ID et nom du VLAN

### Configuration des switchs
Pour chaque switch (Sw01, Sw02) :
- Nombre de ports ACCESS
- Liste des ports ACCESS (ex: g1, g2, g3)
- Nombre de ports TRUNK
- Liste des ports TRUNK (ex: g23, g24)

## 📂 Structure des fichiers

```
Ansible/
├── epreuve.yml                      # Collecte interactive
├── run_all.yml                      # Orchestrateur principal
├── README.md                        # Ce fichier
├── playbooks/                       # Playbooks individuels
│   ├── Active_directory.yml
│   ├── dir_create_ad.yml
│   ├── mappage_lecteur.yml
│   ├── blocage_cmd.yml
│   ├── bloquer_domaines_adguard.yml
│   ├── parefeu.yml
│   ├── Vif_dhcp_routeur.yml
│   └── switchs.yml
└── vars/                            # Variables générées
    └── generated_vars.yml           # Généré automatiquement
```

## ⚠️ Important

- Ne modifiez **jamais** manuellement le fichier `vars/generated_vars.yml`
- Relancez `epreuve.yml` pour régénérer les variables
- Tous les playbooks chargent automatiquement `generated_vars.yml`

## 🔧 Dépannage

### Erreur "vars/generated_vars.yml not found"
→ Lancez d'abord `ansible-playbook Ansible/epreuve.yml`

### Erreur de connexion aux hosts
→ Vérifiez votre inventaire et les connexions SSH/WinRM

### Variables manquantes
→ Relancez `epreuve.yml` pour recollecte les données

## 📊 Exemple de vars/generated_vars.yml

```yaml
ou_name: "Comptabilite"
group_name: "GRP_Compta"
ou_path: "DC=gsb,DC=local"

users:
  - firstname: "Jean"
    lastname: "Dupont"
    username: "jdupont"
    password: "P@ssw0rd123"

domains:
  - "facebook.com"
  - "youtube.com"

switch_ports:
  Sw01:
    access_ports:
      - "g1"
      - "g2"
    trunk_ports:
      - "g24"
  Sw02:
    access_ports:
      - "g1"
    trunk_ports:
      - "g23"
```
