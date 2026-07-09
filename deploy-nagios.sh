#!/bin/bash
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== Déploiement Nagios XI — PRA Alexia ===${NC}"

# Vérification et chargement du kit bootstrap
[ -f .env ] || { echo -e "${RED}.env introuvable${NC}"; exit 1; }
source .env

# - Helper : exécuter une commande Vault via SSH ---
vault_cmd() {
  sshpass -p "$TF_VAR_vault_root_password" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$VAULT_IP \
    "export VAULT_ADDR=http://127.0.0.1:8200; $1"
}

# --- Helper : lire un champ de Vault (nécessite VAULT_TOKEN défini) ---
vget() {
  vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=$1 $2"
}

# =========================================================
# [0/3] Récupération de TOUS les accès depuis Vault (AppRole)
# =========================================================
echo -e "${GREEN}[0/3] Récupération des accès depuis Vault (AppRole)${NC}"

# Authentification AppRole → token temporaire
VAULT_TOKEN=$(vault_cmd "vault write -field=token auth/approle/login \
  role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID")

if [ -z "$VAULT_TOKEN" ]; then
  echo -e "${RED}Échec de l'authentification AppRole${NC}"
  exit 1
fi

# Récupérer toutes les variables depuis Vault
export PROXMOX_HOST=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=host kv/proxmox-ssh")
export PROXMOX_SSH_PASSWORD=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=password kv/proxmox-ssh")
export NAGIOS_VMID=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=nagios_vmid kv/proxmox-ssh")
export NAGIOS_IP=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=nagios_ip kv/proxmox-ssh")
export GRAYLOG_IP=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=graylog_ip kv/proxmox-ssh")
export GRAYLOG_IP_SECONDAIRE=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=graylog_ip_secondaire kv/proxmox-ssh")
export GL_NCPA_TOKEN=$(vget ncpa_token kv/graylog)
export NAS_HOST=$(vget nas_host kv/nas)
export NAS_USER=$(vget nas_user kv/nas)
export NAS_PWD=$(vget nas_pwd kv/nas)
export NAS_PATH_NAGIOS=$(vget nas_path_nagios kv/nas)
export GL_NCPA_TOKEN=$(vget ncpa_token kv/graylog)

# Mot de passe du compte ansible dédié (pour la sauvegarde sécurisée)
export ANSIBLE_ACCOUNT_PASSWORD=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=ansible_password kv/nagiosxi")

# Vérification
if [ -z "$PROXMOX_HOST" ] || [ -z "$NAGIOS_VMID" ] || [ -z "$NAGIOS_IP" ]; then
  echo -e "${RED}Échec de récupération des variables depuis Vault${NC}"
  exit 1
fi
echo -e "${GREEN}Variables récupérées depuis Vault${NC}"

# =========================================================
# [1/3] Terraform : créer le LXC (token Proxmox depuis Vault)
# =========================================================
echo -e "${GREEN}[1/3] Création du LXC Nagios (Terraform)${NC}"
cd terraform/nagios
terraform init -input=false
terraform apply -auto-approve
cd ../..

# =========================================================
# [2/3] Attente du démarrage du LXC (via pct status)
# =========================================================
echo -e "${GREEN}[2/3] Attente du démarrage du LXC${NC}"
for i in $(seq 1 30); do
  STATUS=$(sshpass -p "$PROXMOX_SSH_PASSWORD" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    terraform@$PROXMOX_HOST "sudo pct status $NAGIOS_VMID" 2>/dev/null || echo "")
  if echo "$STATUS" | grep -q "running"; then
    echo -e "${GREEN}LXC démarré${NC}"
    sleep 10
    break
  fi
  echo -e "${YELLOW}Attente $i/30...${NC}"
  sleep 5
  if [ "$i" -eq 30 ]; then
    echo -e "${RED}LXC non démarré après 30 tentatives${NC}"
    exit 1
  fi
done

# =========================================================
# [3/3] Ansible : installer + restaurer Nagios XI
# =========================================================
echo -e "${GREEN}[3/3] Installation + restauration de Nagios XI (Ansible)${NC}"
echo -e "${YELLOW}(l'installation Nagios XI prend 15-30 min, patientez)${NC}"
ansible-playbook -i ansible/inventory-nagios.ini ansible/deploy-nagios.yml

echo -e "${GREEN}=== Nagios XI déployé et restauré ===${NC}"
echo -e "${GREEN}Interface : http://$NAGIOS_IP/nagiosxi/${NC}"
