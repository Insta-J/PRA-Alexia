#!/bin/bash
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== Déploiement Nextcloud + MariaDB — PRA Alexia ===${NC}"

[ -f .env ] || { echo -e "${RED}.env introuvable${NC}"; exit 1; }
source .env
set +H

# --- Helpers Vault ---
vault_cmd() {
  sshpass -p "$TF_VAR_vault_root_password" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$VAULT_IP \
    "export VAULT_ADDR=http://127.0.0.1:8200; $1"
}
vget() {
  vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=$1 $2"
}

# =========================================================
#  [0/6] Récupération des accès depuis Vault
# =========================================================
echo -e "${GREEN}[0/6] Récupération des accès depuis Vault${NC}"
VAULT_TOKEN=$(vault_cmd "vault write -field=token auth/approle/login \
  role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID")

# Proxmox
export PROXMOX_HOST=$(vget host kv/proxmox-ssh)
export PROXMOX_SSH_PASSWORD=$(vget password kv/proxmox-ssh)

# NAS (pour récupérer les backups)
NAS_HOST=$(vget nas_host kv/nas)
NAS_USER=$(vget nas_user kv/nas)
NAS_PWD=$(vget nas_pwd kv/nas)
NAS_PATH_MARIADB=$(vget nas_path_mariadb kv/nas)

# MariaDB (LXC + secrets)
export MARIADB_VMID=$(vget mariadb_vmid kv/proxmox-ssh)
export MARIADB_IP=$(vget mariadb_ip kv/proxmox-ssh)
export DB_ROOT_PASSWORD=$(vget db_root_password kv/mariadb)
export DB_USER=$(vget db_user kv/mariadb)
export DB_PASSWORD=$(vget db_password kv/mariadb)
export DB_NAME=$(vget db_name kv/mariadb)
export NC_NCPADB_TOKEN=$(vget ncpa_token kv/mariadb)

# Nextcloud (LXC + secrets)
export NEXTCLOUD_VMID=$(vget nextcloud_vmid kv/proxmox-ssh)
NEXTCLOUD_IP=$(vget nextcloud_ip kv/proxmox-ssh)
export NC_DB_HOST=$(vget db_host kv/nextcloud)
export NC_DB_USER=$(vget db_user kv/nextcloud)
export NC_DB_PASSWORD=$(vget db_password kv/nextcloud)
export NC_DB_NAME=$(vget db_name kv/nextcloud)
export NC_ADMIN_USER=$(vget admin_user kv/nextcloud)
export NC_ADMIN_PASSWORD=$(vget admin_password kv/nextcloud)
export NC_NCPA_TOKEN=$(vget ncpa_token kv/nextcloud)

# L'IP Nextcloud est nécessaire au playbook MariaDB (droit d'accès distant)
export NEXTCLOUD_IP="$NEXTCLOUD_IP"

# Vérification
if [ -z "$MARIADB_VMID" ] || [ -z "$NEXTCLOUD_VMID" ] || [ -z "$NC_DB_HOST" ]; then
  echo -e "${RED}Variables critiques manquantes${NC}"
  echo "MARIADB_VMID: [$MARIADB_VMID] | NEXTCLOUD_VMID: [$NEXTCLOUD_VMID] | DB_HOST: [$NC_DB_HOST]"
  exit 1
fi
echo -e "${GREEN}Variables récupérées depuis Vault.${NC}"

# =========================================================
# [0b/6] Récupérer le dernier backup SQL + config.php du NAS
# =========================================================
echo -e "${GREEN}[0b/6] Recherche des derniers backups sur le NAS...${NC}"
mkdir -p ansible/files/

# Dernier dump SQL
LATEST_SQL=$(sshpass -p "$NAS_PWD" ssh -o StrictHostKeyChecking=no "$NAS_USER@$NAS_HOST" \
  "ls -t $NAS_PATH_MARIADB/mariadb-*.sql.gz 2>/dev/null | head -1")

# Dernier config.php
LATEST_CONF=$(sshpass -p "$NAS_PWD" ssh -o StrictHostKeyChecking=no "$NAS_USER@$NAS_HOST" \
  "ls -t $NAS_PATH_MARIADB/nextcloud-config-*.php 2>/dev/null | head -1")

if [ -z "$LATEST_SQL" ]; then
  echo -e "${YELLOW}Aucun backup SQL trouvé. Installation vierge.${NC}"
  rm -f ansible/files/nextcloud-latest.sql.gz ansible/files/nextcloud-config.php
else
  echo -e "${YELLOW}Backup SQL détecté : $LATEST_SQL${NC}"
  # Téléchargement SQL (chemin complet /volume1/, PAS de sed)
  sshpass -p "$NAS_PWD" scp -o StrictHostKeyChecking=no \
    "$NAS_USER@$NAS_HOST:$LATEST_SQL" ansible/files/nextcloud-latest.sql.gz

  if [ -n "$LATEST_CONF" ]; then
    echo -e "${YELLOW}Config.php détecté : $LATEST_CONF${NC}"
    # Téléchargement config.php (chemin complet /volume1/, PAS de sed)
    sshpass -p "$NAS_PWD" scp -o StrictHostKeyChecking=no \
      "$NAS_USER@$NAS_HOST:$LATEST_CONF" ansible/files/nextcloud-config.php
  else
    echo -e "${YELLOW}Pas de config.php trouvé.${NC}"
    rm -f ansible/files/nextcloud-config.php
  fi
  echo -e "${GREEN}Backups prêts localement.${NC}"
fi

# =========================================================
# [1/6] Terraform : créer le LXC MariaDB
# =========================================================
echo -e "${GREEN}[1/6] Création du LXC MariaDB (Terraform)${NC}"
cd terraform/mariadb
terraform init -input=false
terraform apply -auto-approve
cd ../..

# =========================================================
# [2/6] Attente du démarrage du LXC MariaDB
# =========================================================
echo -e "${GREEN}[2/6] Attente du démarrage du LXC MariaDB${NC}"
for i in $(seq 1 30); do
  STATUS=$(sshpass -p "$PROXMOX_SSH_PASSWORD" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    terraform@$PROXMOX_HOST "sudo pct status $MARIADB_VMID" 2>/dev/null || echo "")
  if echo "$STATUS" | grep -q "running"; then
    echo -e "${GREEN}LXC MariaDB démarré${NC}"; sleep 10; break
  fi
  echo -e "${YELLOW}Attente $i/30...${NC}"; sleep 5
done

# =========================================================
# [3/6] Ansible : installer MariaDB (base distante, VIDE)
# =========================================================
echo -e "${GREEN}[3/6] Installation MariaDB (Ansible)${NC}"
ansible-playbook -i ansible/inventory-mariadb.ini ansible/deploy-mariadb.yml

# =========================================================
# [4/6] Terraform : créer le LXC Nextcloud
# =========================================================
echo -e "${GREEN}[4/6] Création du LXC Nextcloud (Terraform)${NC}"
cd terraform/nextcloud
terraform init -input=false
terraform apply -auto-approve
cd ../..

# =========================================================
# [5/6] Attente du démarrage du LXC Nextcloud
# =========================================================
echo -e "${GREEN}[5/6] Attente du démarrage du LXC Nextcloud${NC}"
for i in $(seq 1 30); do
  STATUS=$(sshpass -p "$PROXMOX_SSH_PASSWORD" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    terraform@$PROXMOX_HOST "sudo pct status $NEXTCLOUD_VMID" 2>/dev/null || echo "")
  if echo "$STATUS" | grep -q "running"; then
    echo -e "${GREEN}LXC Nextcloud démarré${NC}"; sleep 10; break
  fi
  echo -e "${YELLOW}Attente $i/30...${NC}"; sleep 5
done

# =========================================================
# [6/6] Ansible : installer Nextcloud + restaurer (SQL + config.php)
# =========================================================
echo -e "${GREEN}[6/6] Installation Nextcloud (Ansible)${NC}"
ansible-playbook -i ansible/inventory-nextcloud.ini ansible/deploy-nextcloud.yml

echo -e "${GREEN}=== Déploiement terminé ===${NC}"
echo -e "${GREEN}MariaDB : $MARIADB_IP (Vlan50)${NC}"
echo -e "${GREEN}Nextcloud : http://$NEXTCLOUD_IP/ (Vlan40)${NC}"
# =========================================================
# [7/7] Restauration des données (SQL via MariaDB, APRÈS install)
# =========================================================
echo -e "${GREEN}[7/7] Restauration des données Nextcloud${NC}"
ansible-playbook -i ansible/inventory-mariadb.ini -i ansible/inventory-nextcloud.ini ansible/restore-nextcloud.yml

echo -e "${GREEN}=== Déploiement + restauration terminés ===${NC}"
echo -e "${GREEN}Nextcloud : http://$NEXTCLOUD_IP/ (Vlan40)${NC}"
