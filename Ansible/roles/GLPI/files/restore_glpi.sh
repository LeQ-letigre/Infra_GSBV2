#!/bin/bash
# Script de restauration GLPI
# Restaure la base de données et les volumes Docker à partir d'une sauvegarde

set -e

# Vérifier les arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_name>"
    echo "Exemple: $0 glpi_backup_20250102_143000"
    echo ""
    echo "Sauvegardes disponibles:"
    ls -1 /opt/glpi/backups/*_db.sql 2>/dev/null | sed 's/_db.sql//' | xargs -n1 basename || echo "Aucune sauvegarde trouvée"
    exit 1
fi

BACKUP_DIR="/opt/glpi/backups"
BACKUP_NAME="$1"
DB_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_db.sql"
VOLUMES_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_volumes.tar.gz"

# Vérifier que les fichiers existent
if [ ! -f "${DB_BACKUP}" ]; then
    echo "Erreur: Fichier ${DB_BACKUP} introuvable"
    exit 1
fi

if [ ! -f "${VOLUMES_BACKUP}" ]; then
    echo "Erreur: Fichier ${VOLUMES_BACKUP} introuvable"
    exit 1
fi

echo "=========================================="
echo "Restauration GLPI - ${BACKUP_NAME}"
echo "=========================================="
echo "ATTENTION: Cette opération va écraser les données actuelles !"
read -p "Continuer ? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restauration annulée"
    exit 1
fi

# Arrêter GLPI
echo "[1/4] Arrêt de GLPI..."
cd /opt/glpi && docker compose down

# Restaurer la base de données
echo "[2/4] Restauration de la base de données..."
cd /opt/glpi && docker compose up -d glpi_db
sleep 10
docker exec -i glpi_db mysql -u glpi -pglpi glpi < "${DB_BACKUP}"

# Restaurer les volumes
echo "[3/4] Restauration des fichiers GLPI..."
docker run --rm \
  -v glpi_config:/config \
  -v glpi_files:/files \
  -v glpi_plugins:/plugins \
  -v glpi_marketplace:/marketplace \
  -v "${BACKUP_DIR}:/backup" \
  alpine sh -c "cd / && tar xzf /backup/${BACKUP_NAME}_volumes.tar.gz"

# Redémarrer GLPI
echo "[4/4] Redémarrage de GLPI..."
cd /opt/glpi && docker compose up -d

echo "=========================================="
echo "Restauration terminée avec succès !"
echo "GLPI devrait être accessible dans quelques secondes."
echo "=========================================="
