#!/bin/bash
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== Déploiement Graylog — PRA Alexia ===${NC}"

[ -f .env ] || { echo -e "${RED}.env introuvable${NC}"; exit 1; }
source .env
set +H

# --- Helper : commande Vault via SSH ---
vault_cmd() {
  sshpass -p "$TF_VAR_vault_root_password" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$VAULT_IP \
    "export VAULT_ADDR=http://127.0.0.1:8200; $1"
}

# --- Helper : lire un champ de Vault ---
vget() {
  vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=$1 $2"
}

# =========================================================
# [0/4]  Récupération de TOUS les accès depuis Vault (AppRole)
# =========================================================
echo -e "${GREEN}[0/4] Récupération des accès depuis Vault (AppRole)${NC}"

VAULT_TOKEN=$(vault_cmd "vault write -field=token auth/approle/login \
  role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID")

if [ -z "$VAULT_TOKEN" ]; then
  echo -e "${RED}Échec authentification AppRole${NC}"; exit 1
fi

# Connexion Proxmox
export PROXMOX_HOST=$(vget host kv/proxmox-ssh)
export PROXMOX_SSH_PASSWORD=$(vget password kv/proxmox-ssh)
export GRAYLOG_VMID=$(vget graylog_vmid kv/proxmox-ssh)
GRAYLOG_IP=$(vget graylog_ip kv/proxmox-ssh)

# Secrets Graylog
export GL_PASSWORD_SECRET=$(vget password_secret kv/graylog)
export GL_ROOT_SHA2=$(vget root_password_sha2 kv/graylog)
export GL_MONGODB_URI=$(vget mongodb_uri kv/graylog)
export GL_MONGO_USER=$(vget mongo_user kv/graylog)
export GL_MONGO_PASSWORD=$(vget mongo_password kv/graylog)
export GL_NCPA_TOKEN=$(vget ncpa_token kv/graylog)


# NAS
export NAS_HOST=$(vget nas_host kv/nas)
export NAS_USER=$(vget nas_user kv/nas)
export NAS_PWD=$(vget nas_pwd kv/nas)
export NAS_PATH=$(vget nas_path kv/nas)

# Vérification des variables critiques
if [ -z "$GRAYLOG_VMID" ] || [ -z "$GL_MONGODB_URI" ] || [ -z "$GL_PASSWORD_SECRET" ]; then
  echo -e "${RED}Variables critiques manquantes depuis Vault${NC}"
  echo "VMID: [$GRAYLOG_VMID] | URI vide: [$([ -z "$GL_MONGODB_URI" ] && echo OUI)]"
  exit 1
fi
echo -e "${GREEN}Variables récupérées (VMID: $GRAYLOG_VMID)${NC}"

# =========================================================
# [1/4] Prérequis hôte : vm.max_map_count (vérification seule)
# =========================================================
echo -e "${GREEN}[1/4] Vérification vm.max_map_count sur l'hôte${NC}"
CURRENT_MMC=$(sshpass -p "$PROXMOX_SSH_PASSWORD" ssh \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  terraform@$PROXMOX_HOST "/usr/sbin/sysctl -n vm.max_map_count" 2>/dev/null || echo "0")

if [ "$CURRENT_MMC" -lt 262144 ]; then
  echo -e "${RED}vm.max_map_count = $CURRENT_MMC (insuffisant pour OpenSearch)${NC}"
  echo -e "${YELLOW}Configurez-le sur l'hôte Proxmox en root (une seule fois) :${NC}"
  echo -e "${YELLOW}  echo 'vm.max_map_count=262144' > /etc/sysctl.d/99-graylog.conf${NC}"
  echo -e "${YELLOW}  sysctl -p /etc/sysctl.d/99-graylog.conf${NC}"
  exit 1
else
  echo -e "${GREEN}vm.max_map_count OK ($CURRENT_MMC)${NC}"
fi
# =========================================================
# [2/4] Terraform : créer le LXC
# =========================================================
echo -e "${GREEN}[2/4] Création du LXC Graylog (Terraform)${NC}"
cd terraform/graylog
terraform init -input=false
terraform apply -auto-approve
cd ../..

# =========================================================
# [3/4] Attente du démarrage du LXC
# =========================================================
echo -e "${GREEN}[3/4] Attente du démarrage du LXC${NC}"
for i in $(seq 1 30); do
  STATUS=$(sshpass -p "$PROXMOX_SSH_PASSWORD" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    terraform@$PROXMOX_HOST "sudo pct status $GRAYLOG_VMID" 2>/dev/null || echo "")
  if echo "$STATUS" | grep -q "running"; then
    echo -e "${GREEN}LXC démarré${NC}"; sleep 10; break
  fi
  echo -e "${YELLOW}Attente $i/30...${NC}"; sleep 5
done

# =========================================================
# [4/4] Ansible : installer Graylog + restaurer
# =========================================================
echo -e "${GREEN}[4/4] Installation + restauration de Graylog (Ansible)${NC}"
echo -e "${YELLOW}(installation longue : MongoDB + Graylog + OpenSearch, ~20 min)${NC}"
ansible-playbook -i ansible/inventory-graylog.ini ansible/deploy-graylog.yml

echo -e "${GREEN}=== Graylog déployé et restauré ===${NC}"
echo -e "${GREEN}Interface : http://$GRAYLOG_IP:9000 (attendre ~2 min le démarrage complet)${NC}"
