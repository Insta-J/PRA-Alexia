#!/bin/bash
set -e
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
LOCAL_TMP="/root/mariadb_backups"
DATE=$(date +%Y%m%d-%H%M)

echo -e "${GREEN}=== Sauvegarde MariaDB + config.php -> NAS (Rétention : 5) ===${NC}"

[ -f .env ] || { echo -e "${RED}.env introuvable${NC}"; exit 1; }
source .env
set +H
mkdir -p "$LOCAL_TMP"

vault_cmd() {
  sshpass -p "$TF_VAR_vault_root_password" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$VAULT_IP "export VAULT_ADDR=http://127.0.0.1:8200; $1"
}
vget() {
  vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=$1 $2"
}

echo -e "${GREEN}==> [1/5] Connexion à Vault${NC}"
VAULT_TOKEN=$(vault_cmd "vault write -field=token auth/approle/login role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID")
[ -z "$VAULT_TOKEN" ] && { echo -e "${RED}Échec AppRole${NC}"; exit 1; }

# NAS
NAS_USER=$(vget nas_user kv/nas)
NAS_HOST=$(vget nas_host kv/nas)
NAS_PWD=$(vget nas_pwd kv/nas)
NAS_PATH=$(vget nas_path_mariadb kv/nas)

# MariaDB
MARIADB_IP=$(vget mariadb_ip kv/proxmox-ssh)
DB_ROOT_PASSWORD=$(vget db_root_password kv/mariadb)
DB_NAME=$(vget db_name kv/mariadb)
DB_NAME=${DB_NAME:-nextcloud}

# Nextcloud (pour récupérer config.php)
NEXTCLOUD_IP=$(vget nextcloud_ip kv/proxmox-ssh)
NC_LXC_PASSWORD=$(vget root_password kv/nextcloud)

if [ -z "$NAS_HOST" ] || [ -z "$DB_ROOT_PASSWORD" ]; then
  echo -e "${RED}Secrets manquants${NC}"; exit 1
fi

# =========================================================
# [2/5] Dump MariaDB
# =========================================================
echo -e "${GREEN}==> [2/5] Dump MariaDB '${DB_NAME}'${NC}"
ARCHIVE_SQL="${LOCAL_TMP}/mariadb-${DB_NAME}-${DATE}.sql.gz"
sshpass -p "$DB_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no root@"$MARIADB_IP" \
  "mysqldump -u root -p'${DB_ROOT_PASSWORD}' --single-transaction --quick --databases ${DB_NAME} | gzip -c" > "$ARCHIVE_SQL"

# =========================================================
# [3/5] Récupérer le config.php de Nextcloud
# =========================================================
echo -e "${GREEN}==> [3/5] Sauvegarde du config.php Nextcloud${NC}"
ARCHIVE_CONF="${LOCAL_TMP}/nextcloud-config-${DATE}.php"
sshpass -p "$NC_LXC_PASSWORD" scp -o StrictHostKeyChecking=no \
  root@"$NEXTCLOUD_IP":/var/www/nextcloud/config/config.php \
  "$ARCHIVE_CONF"

# =========================================================
# [4/5] Envoi vers le NAS (les deux fichiers)
# =========================================================
echo -e "${GREEN}==> [4/5] Envoi vers le NAS${NC}"
sshpass -p "$NAS_PWD" scp -o StrictHostKeyChecking=no "$ARCHIVE_SQL" "${NAS_USER}@${NAS_HOST}:${NAS_PATH}/"
sshpass -p "$NAS_PWD" scp -o StrictHostKeyChecking=no "$ARCHIVE_CONF" "${NAS_USER}@${NAS_HOST}:${NAS_PATH}/"
SCP_RC=$?

# =========================================================
# [5/5] Rétention locale (5 derniers de chaque type)
# =========================================================
echo -e "${GREEN}==> [5/5] Rétention (5 derniers)${NC}"
cd "$LOCAL_TMP"
ls -t mariadb-*.sql.gz 2>/dev/null | tail -n +6 | xargs -I {} rm -f {}
ls -t nextcloud-config-*.php 2>/dev/null | tail -n +6 | xargs -I {} rm -f {}

if [ $SCP_RC -eq 0 ] && [ -s "$ARCHIVE_SQL" ]; then
    echo -e "${GREEN}==> [OK] Sauvegarde réussie (SQL + config.php)${NC}"
    echo "$(date '+%F %T') OK mariadb=${ARCHIVE_SQL} config=${ARCHIVE_CONF}" >> /root/mariadb_backup.log
    exit 0
else
    echo -e "${RED}==> [ERREUR] Échec envoi NAS (rc=$SCP_RC)${NC}"
    echo "$(date '+%F %T') FAIL rc=$SCP_RC" >> /root/mariadb_backup.log
    exit 1
fi
