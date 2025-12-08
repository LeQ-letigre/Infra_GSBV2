# Rôle Ansible GLPI

Déploiement automatisé de GLPI (Gestion Libre de Parc Informatique) avec Docker et configuration automatique.

## Caractéristiques

- ✅ Déploiement GLPI 11.0.2 (dernière version stable)
- ✅ Base de données MariaDB 11.0
- ✅ Installation automatique via CLI (pas de setup manuel)
- ✅ Configuration LDAP/Active Directory automatique
- ✅ Volumes Docker persistants
- ✅ Cron configuré pour les tâches automatiques
- ✅ Scripts de sauvegarde/restauration inclus
- ✅ Support Ansible Vault pour les secrets

## Prérequis

- Docker et Docker Compose installés sur la machine cible
- Collection Ansible `community.docker` installée
- Accès réseau au serveur LDAP (si configuration LDAP activée)

## Structure du rôle

```
GLPI/
├── defaults/main.yml          # Variables par défaut
├── handlers/main.yml          # Handlers de redémarrage
├── tasks/
│   ├── main.yml              # Tâches principales
│   └── configure_ldap.yml    # Configuration LDAP
├── templates/
│   └── docker-compose.yml.j2 # Template Docker Compose
├── files/
│   ├── backup_glpi.sh        # Script de sauvegarde
│   └── restore_glpi.sh       # Script de restauration
└── README.md                 # Ce fichier
```

## Variables

### Configuration GLPI

| Variable | Défaut | Description |
|----------|--------|-------------|
| `glpi_version` | `11.0.2` | Version de GLPI |
| `glpi_port` | `8080` | Port d'écoute HTTP |
| `glpi_timezone` | `Europe/Paris` | Fuseau horaire |
| `mariadb_version` | `11.0` | Version MariaDB |

### Base de données

| Variable | Défaut | Description |
|----------|--------|-------------|
| `glpi_mysql_db` | `glpi` | Nom de la base de données |
| `glpi_mysql_user` | `glpi` | Utilisateur MySQL |
| `glpi_mysql_password` | `ChangeMe_GlpiPassword` | Mot de passe MySQL (utiliser Vault) |
| `glpi_mysql_root_password` | `ChangeMe_RootPassword` | Mot de passe root MySQL (utiliser Vault) |

### Compte administrateur GLPI

| Variable | Défaut | Description |
|----------|--------|-------------|
| `glpi_admin_user` | `glpi` | Utilisateur admin par défaut |
| `glpi_admin_password` | `glpi` | Mot de passe admin (utiliser Vault) |

### Configuration LDAP (optionnel)

| Variable | Défaut | Description |
|----------|--------|-------------|
| `glpi_ldap_enabled` | `false` | Activer la configuration LDAP |
| `glpi_ldap_name` | `Active Directory GSB` | Nom du serveur LDAP |
| `glpi_ldap_host` | `ad.gsb.local` | Hôte LDAP |
| `glpi_ldap_port` | `636` | Port LDAP (636 pour LDAPS) |
| `glpi_ldap_basedn` | `DC=gsb,DC=local` | Base DN |
| `glpi_ldap_rootdn` | `CN=glpi_bind,...` | DN de compte de liaison |
| `glpi_ldap_password` | - | Mot de passe du compte de liaison |
| `glpi_ldap_use_tls` | `true` | Utiliser TLS/SSL |
| `glpi_ldap_login_field` | `samaccountname` | Champ de connexion |

## Utilisation

### 1. Déploiement simple

Créer un playbook `deploy_glpi.yml`:

```yaml
---
- name: Déployer GLPI
  hosts: glpi_servers
  become: yes
  roles:
    - GLPI
```

Exécuter:
```bash
ansible-playbook -i inventory.yml deploy_glpi.yml
```

### 2. Déploiement avec configuration personnalisée

Créer un fichier de variables `group_vars/glpi_servers.yml`:

```yaml
---
glpi_port: 80
glpi_timezone: "Europe/Paris"

# Configuration LDAP
glpi_ldap_enabled: true
glpi_ldap_host: "ad.example.com"
glpi_ldap_port: 636
glpi_ldap_basedn: "DC=example,DC=com"
glpi_ldap_rootdn: "CN=glpi_service,OU=ServiceAccounts,DC=example,DC=com"
```

### 3. Sécuriser les mots de passe avec Ansible Vault

Créer un fichier vault `group_vars/glpi_servers/vault.yml`:

```bash
ansible-vault create group_vars/glpi_servers/vault.yml
```

Contenu:
```yaml
---
vault_glpi_mysql_root_password: "SuperSecretRootPassword"
vault_glpi_mysql_password: "SecureGlpiPassword"
vault_glpi_admin_password: "SecureAdminPassword"
vault_ldap_bind_password: "LdapBindPassword"
```

Exécuter avec vault:
```bash
ansible-playbook -i inventory.yml deploy_glpi.yml --ask-vault-pass
```

## Première connexion

Après le déploiement, GLPI est accessible à l'adresse:
```
http://<ip_serveur>:8080
```

**Identifiants par défaut:**
- Utilisateur: `glpi`
- Mot de passe: `glpi` (ou la valeur de `glpi_admin_password`)

**⚠️ IMPORTANT:** Changez immédiatement le mot de passe après la première connexion !

## Sauvegarde et restauration

### Sauvegarde automatique

Un script de sauvegarde est déployé dans `/opt/glpi/backup_glpi.sh`.

**Lancer une sauvegarde manuelle:**
```bash
bash /opt/glpi/backup_glpi.sh
```

**Automatiser avec cron (quotidien à 2h):**
```bash
crontab -e
# Ajouter:
0 2 * * * /opt/glpi/backup_glpi.sh >> /var/log/glpi_backup.log 2>&1
```

Les sauvegardes sont stockées dans `/opt/glpi/backups/` et conservées 7 jours par défaut.

### Restauration

**Lister les sauvegardes disponibles:**
```bash
bash /opt/glpi/restore_glpi.sh
```

**Restaurer une sauvegarde:**
```bash
bash /opt/glpi/restore_glpi.sh glpi_backup_20250102_143000
```

## Maintenance

### Mettre à jour GLPI

Modifier la version dans `defaults/main.yml`:
```yaml
glpi_version: "11.0.3"  # Nouvelle version
```

Relancer le playbook:
```bash
ansible-playbook -i inventory.yml deploy_glpi.yml
```

La mise à jour de la base de données est automatique via `php bin/console db:update`.

### Accéder aux logs

**Logs GLPI:**
```bash
docker logs glpi
```

**Logs MariaDB:**
```bash
docker logs glpi_db
```

**Logs GLPI dans le conteneur:**
```bash
docker exec -it glpi tail -f /var/www/html/files/_log/php-errors.log
```

### Commandes utiles

**Redémarrer GLPI:**
```bash
cd /opt/glpi && docker compose restart
```

**Arrêter GLPI:**
```bash
cd /opt/glpi && docker compose down
```

**Accéder au shell GLPI:**
```bash
docker exec -it glpi bash
```

**Accéder à la console MySQL:**
```bash
docker exec -it glpi_db mysql -u glpi -p glpi
```

**Exécuter une commande CLI GLPI:**
```bash
docker exec glpi php bin/console <commande>
```

Exemples:
```bash
# Vérifier l'état de la base
docker exec glpi php bin/console db:check

# Synchroniser les utilisateurs LDAP
docker exec glpi php bin/console glpi:ldap:synchronize_users -c

# Lister les plugins
docker exec glpi php bin/console glpi:plugin:list
```

## Volumes Docker

Les données persistantes sont stockées dans les volumes Docker:

| Volume | Contenu |
|--------|---------|
| `glpi_db_data` | Base de données MariaDB |
| `glpi_config` | Fichiers de configuration GLPI |
| `glpi_files` | Documents uploadés par les utilisateurs |
| `glpi_marketplace` | Plugins du marketplace |
| `glpi_plugins` | Plugins personnalisés |

**Inspecter les volumes:**
```bash
docker volume ls | grep glpi
docker volume inspect glpi_db_data
```

## Dépannage

### GLPI ne démarre pas

Vérifier les logs:
```bash
docker logs glpi
docker logs glpi_db
```

Vérifier que la base de données est accessible:
```bash
docker exec glpi_db mysqladmin ping -h localhost
```

### Erreur de connexion LDAP

Tester la connexion depuis le conteneur:
```bash
docker exec glpi apt-get update && apt-get install -y ldap-utils
docker exec glpi ldapsearch -H ldaps://ad.gsb.local:636 -D "CN=glpi_bind,..." -W -b "DC=gsb,DC=local"
```

### Réinitialiser complètement GLPI

**⚠️ ATTENTION: Ceci supprime toutes les données !**

```bash
cd /opt/glpi
docker compose down -v  # -v supprime les volumes
docker volume rm glpi_db_data glpi_config glpi_files glpi_marketplace glpi_plugins
ansible-playbook -i inventory.yml deploy_glpi.yml  # Redéployer
```

## Support et documentation

- Documentation officielle GLPI: https://glpi-install.readthedocs.io/
- GitHub GLPI: https://github.com/glpi-project/glpi
- Forum GLPI: https://forum.glpi-project.org/

## Licence

Ce rôle Ansible est fourni tel quel, sans garantie.
