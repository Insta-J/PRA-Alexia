#!/bin/bash
set -e
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
LOCAL_TMP="/root/nagios_backups"
DATE=$(date +%Y%m%d-%H%M)

echo -e "${GREEN}=== Sauvegarde Nagios -> NAS (Rétention : 5) ===${NC}"

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
NAS_PATH=$(vget nas_path_nagios kv/nas)

# Nagios
NAGIOS_IP=$(vget nagios_ip kv/proxmox-ssh)
NAGIOS_ROOT_PASSWORD=$(vget root_password kv/nagiosxi)

if [ -z "$NAS_HOST" ] || [ -z "$NAGIOS_ROOT_PASSWORD" ] || [ -z "$NAS_PATH" ]; then
  echo -e "${RED}Secrets manquants${NC}"; exit 1
fi

# =========================================================
# [2/4] Création de l'archive Nagios à distance
# =========================================================
echo -e "${GREEN}==> [2/4] Création de l'archive sur Nagios (${NAGIOS_IP})${NC}"
ARCHIVE_NAGIOS="${LOCAL_TMP}/nagios-backup-${DATE}.tar.gz"

sshpass -p "$NAGIOS_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no root@"$NAGIOS_IP" \
  "tar -czf - /usr/local/nagios/etc /usr/local/nagios/var/retention.dat /usr/local/nagios/var/archives 2>/dev/null" > "$ARCHIVE_NAGIOS"

# =========================================================
# [3/4] Envoi vers le NAS
# =========================================================
echo -e "${GREEN}==> [3/4] Envoi vers le NAS${NC}"

# On s'assure juste que le chemin commence par un seul slash '/' 
# en utilisant la valeur brute de Vault (qui contient déjà /volume1)
REAL_NAS_PATH="/${NAS_PATH#/}"

sshpass -p "$NAS_PWD" scp -o StrictHostKeyChecking=no "$ARCHIVE_NAGIOS" "${NAS_USER}@${NAS_HOST}:${REAL_NAS_PATH}/"
SCP_RC=$?

# =========================================================
# [4/4] Rétention locale (5 derniers)
# =========================================================
echo -e "${GREEN}==> [4/4] Rétention (5 derniers)${NC}"
cd "$LOCAL_TMP"
ls -t nagios-backup-*.tar.gz 2>/dev/null | tail -n +6 | xargs -I {} rm -f {}

if [ $SCP_RC -eq 0 ] && [ -s "$ARCHIVE_NAGIOS" ]; then
    echo -e "${GREEN}==> [OK] Sauvegarde réussie (Nagios Configuration + Data)${NC}"
    echo "$(date '+%F %T') OK nagios=${ARCHIVE_NAGIOS}" >> /root/nagios_backup.log
    exit 0
else
    echo -e "${RED}==> [ERREUR] Échec envoi NAS (rc=$SCP_RC)${NC}"
    echo "$(date '+%F %T') FAIL rc=$SCP_RC" >> /root/nagios_backup.log
    exit 1
fi
