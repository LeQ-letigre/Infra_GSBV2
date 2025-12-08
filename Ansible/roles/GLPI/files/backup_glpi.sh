#!/bin/bash
# Script de sauvegarde automatique GLPI
# Sauvegarde la base de données et les volumes Docker

set -e

# Configuration
BACKUP_DIR="/opt/glpi/backups"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="glpi_backup_${DATE}"

# Créer le dossier de backup
mkdir -p "${BACKUP_DIR}"

echo "=========================================="
echo "Sauvegarde GLPI - ${DATE}"
echo "=========================================="

# 1. Backup de la base de données
echo "[1/3] Sauvegarde de la base de données..."
docker exec glpi_db mysqldump -u glpi -pglpi glpi > "${BACKUP_DIR}/${BACKUP_NAME}_db.sql"

# 2. Backup des volumes Docker (config, files, plugins, marketplace)
echo "[2/3] Sauvegarde des fichiers GLPI..."
docker run --rm \
  -v glpi_config:/config \
  -v glpi_files:/files \
  -v glpi_plugins:/plugins \
  -v glpi_marketplace:/marketplace \
  -v "${BACKUP_DIR}:/backup" \
  alpine tar czf "/backup/${BACKUP_NAME}_volumes.tar.gz" /config /files /plugins /marketplace

# 3. Nettoyage des anciennes sauvegardes
echo "[3/3] Nettoyage des sauvegardes de plus de ${RETENTION_DAYS} jours..."
find "${BACKUP_DIR}" -name "glpi_backup_*" -mtime +${RETENTION_DAYS} -delete

echo "=========================================="
echo "Sauvegarde terminée avec succès !"
echo "Fichiers:"
echo "  - ${BACKUP_DIR}/${BACKUP_NAME}_db.sql"
echo "  - ${BACKUP_DIR}/${BACKUP_NAME}_volumes.tar.gz"
echo "=========================================="
