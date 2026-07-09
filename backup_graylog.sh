#!/bin/bash
set -e
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
LOCAL_TMP="/root/graylog_backups"
DATE=$(date +%Y%m%d-%H%M)

echo -e "${GREEN}=== Sauvegarde Graylog (MongoDB uniquement) -> NAS (Rétention : 5) ===${NC}"

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

echo -e "${GREEN}==> [1/4] Connexion à Vault${NC}"
VAULT_TOKEN=$(vault_cmd "vault write -field=token auth/approle/login role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID")
[ -z "$VAULT_TOKEN" ] && { echo -e "${RED}Échec AppRole${NC}"; exit 1; }

# NAS
NAS_USER=$(vget nas_user kv/nas)
NAS_HOST=$(vget nas_host kv/nas)
NAS_PWD=$(vget nas_pwd kv/nas)
NAS_PATH=$(vget nas_path_graylog kv/nas)

# Graylog
GRAYLOG_IP=$(vget graylog_ip kv/proxmox-ssh)
GRAYLOG_ROOT_PASSWORD=$(vget root_lxc_password kv/graylog) # Ajuste le chemin si c'est dans kv/proxmox-ssh

if [ -z "$NAS_HOST" ] || [ -z "$GRAYLOG_ROOT_PASSWORD" ] || [ -z "$NAS_PATH" ]; then
  echo -e "${RED}Secrets manquants${NC}"; exit 1
fi

# =========================================================
# [2/4] Dump de la base de données MongoDB
# =========================================================
echo -e "${GREEN}==> [2/4] Dump MongoDB sur Graylog (${GRAYLOG_IP})${NC}"
ARCHIVE_GRAYLOG="${LOCAL_TMP}/graylog-mongo-${DATE}.tar.gz"

# 1. On extrait dynamiquement la chaîne de connexion (URI) configurée dans Graylog
MONGO_URI=$(sshpass -p "$GRAYLOG_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no root@"$GRAYLOG_IP" \
  "grep '^mongodb_uri' /etc/graylog/server/server.conf | cut -d'=' -f2- | tr -d ' ' | tr -d '\r'")

# 2. On exécute le mongodump en lui passant l'URI d'authentification
sshpass -p "$GRAYLOG_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no root@"$GRAYLOG_IP" \
  "mongodump --uri='${MONGO_URI}' --gzip --archive=-" > "$ARCHIVE_GRAYLOG"
# =========================================================
# [3/4] Envoi vers le NAS
# =========================================================
echo -e "${GREEN}==> [3/4] Envoi vers le NAS${NC}"

# On s'assure que le chemin commence par un seul slash '/'
REAL_NAS_PATH="/${NAS_PATH#/}"

sshpass -p "$NAS_PWD" scp -o StrictHostKeyChecking=no "$ARCHIVE_GRAYLOG" "${NAS_USER}@${NAS_HOST}:${REAL_NAS_PATH}/"
SCP_RC=$?

# =========================================================
# [4/4] Rétention locale (5 derniers de chaque type)
# =========================================================
echo -e "${GREEN}==> [4/4] Rétention (5 derniers)${NC}"
cd "$LOCAL_TMP"
ls -t graylog-mongo-*.archive.gz 2>/dev/null | tail -n +6 | xargs -I {} rm -f {}
ls -t graylog-config-*.tar.gz 2>/dev/null | tail -n +6 | xargs -I {} rm -f {}

if [ $SCP_RC -eq 0 ] && [ -s "$ARCHIVE_GRAYLOG" ]; then
    echo -e "${GREEN}==> [OK] Sauvegarde réussie (Graylog MongoDB)${NC}"
    echo "$(date '+%F %T') OK graylog_mongo=${ARCHIVE_GRAYLOG}" >> /root/graylog_backup.log
    exit 0
else
    echo -e "${RED}==> [ERREUR] Échec envoi NAS (rc=$SCP_RC)${NC}"
    echo "$(date '+%F %T') FAIL rc=$SCP_RC" >> /root/graylog_backup.log
    exit 1
fi
