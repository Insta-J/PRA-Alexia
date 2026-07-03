#!/bin/bash
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== Déploiement Nextcloud — PRA Alexia ===${NC}"

[ -f .env ] || { echo -e "${RED}.env introuvable${NC}"; exit 1; }
source .env

vault_cmd() {
  sshpass -p "$TF_VAR_vault_root_password" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$VAULT_IP \
    "export VAULT_ADDR=http://127.0.0.1:8200; $1"
}

# [0] Récupération depuis Vault
echo -e "${GREEN}[0/3] Récupération des accès depuis Vault${NC}"
VAULT_TOKEN=$(vault_cmd "vault write -field=token auth/approle/login \
  role_id=$VAULT_ROLE_ID secret_id=$VAULT_SECRET_ID")

export PROXMOX_HOST=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=host kv/proxmox-ssh")
export PROXMOX_SSH_PASSWORD=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=password kv/proxmox-ssh")
export NEXTCLOUD_VMID=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=nextcloud_vmid kv/proxmox-ssh")
NEXTCLOUD_IP=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=nextcloud_ip kv/proxmox-ssh")

# Secrets Nextcloud
export NC_DB_ROOT_PASSWORD=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=db_root_password kv/nextcloud")
export NC_DB_USER=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=db_user kv/nextcloud")
export NC_DB_PASSWORD=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=db_password kv/nextcloud")
export NC_ADMIN_USER=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=admin_user kv/nextcloud")
export NC_ADMIN_PASSWORD=$(vault_cmd "export VAULT_TOKEN=$VAULT_TOKEN; vault kv get -field=admin_password kv/nextcloud")

echo -e "${GREEN}Variables récupérées${NC}"

# [1] Terraform
echo -e "${GREEN}[1/3] Création du LXC Nextcloud (Terraform)${NC}"
cd terraform/nextcloud
terraform init -input=false
terraform apply -auto-approve
cd ../..

# [2] Attente
echo -e "${GREEN}[2/3] Attente du démarrage du LXC${NC}"
for i in $(seq 1 30); do
  STATUS=$(sshpass -p "$PROXMOX_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null terraform@$PROXMOX_HOST "sudo pct status $NEXTCLOUD_VMID" 2>/dev/null || echo "")
  if echo "$STATUS" | grep -q "running"; then
    echo -e "${GREEN}LXC démarré${NC}"; sleep 10; break
  fi
  sleep 5
done

# [3] Ansible
echo -e "${GREEN}[3/3] Installation Nextcloud + MariaDB (Ansible)${NC}"
ansible-playbook -i ansible/inventory-nextcloud.ini ansible/deploy-nextcloud.yml

echo -e "${GREEN}=== Nextcloud déployé — http://$NEXTCLOUD_IP/ ===${NC}"
