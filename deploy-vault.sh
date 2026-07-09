#!/bin/bash
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

VAULT_IP="192.168.50.4"
PROXMOX_HOST="192.168.1.23"
LXC_ID="131"

echo -e "${GREEN}=== PRA Vault — Déploiement + Restauration ===${NC}"

[ -f .env ] || { echo -e "${RED}.env introuvable${NC}"; exit 1; }
source .env

# -- Détection automatique du dernier snapshot local ---
# Cherche le fichier .snap le plus récent dans le dossier ansible/files/
SNAPSHOT=$(ls -t ansible/files/vault-snapshot-*.snap 2>/dev/null | head -1 | xargs basename)

if [ -z "$SNAPSHOT" ]; then
    echo -e "${RED}Erreur : Aucun snapshot Vault (.snap) trouvé dans ansible/files/${NC}"
    exit 1
fi

echo -e "${YELLOW}Dernier snapshot Vault détecté : $SNAPSHOT${NC}"

# Fonction : exécuter une commande dans le LXC Vault via SSH direct
vault_exec() {
  sshpass -p "$TF_VAR_vault_root_password" ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$VAULT_IP \
    "export VAULT_ADDR=http://127.0.0.1:8200; $1"
}

# --- 1. Terraform : créer le LXC ---
echo -e "${GREEN}[1/6] Création du LXC Vault (Terraform)${NC}"
cd terraform/vault
terraform init -input=false
terraform apply -auto-approve
cd ../..

# --- 2. Ansible : installer Vault ---
echo -e "${GREEN}[2/6] Installation de Vault (Ansible)${NC}"
sleep 20
ansible-playbook -i ansible/inventory-vault.ini ansible/deploy-vault.yml

# --- 3. Init temporaire (1 clé jetable) ---
echo -e "${GREEN}[3/6] Initialisation temporaire${NC}"
sleep 5
INIT_JSON=$(vault_exec "vault operator init -key-shares=1 -key-threshold=1 -format=json")
TEMP_UNSEAL=$(echo "$INIT_JSON" | jq -r '.unseal_keys_b64[0]')
TEMP_TOKEN=$(echo "$INIT_JSON" | jq -r '.root_token')
echo "Clé temporaire extraite : ${TEMP_UNSEAL:0:10}..."

# --- 4. Unseal temporaire ---
echo -e "${GREEN}[4/6] Déverrouillage temporaire${NC}"
vault_exec "vault operator unseal $TEMP_UNSEAL"

# --- 5. Transfert SCP + Restauration ---
echo -e "${GREEN}[5/6] Transfert et restauration du snapshot${NC}"
sshpass -p "$TF_VAR_vault_root_password" scp \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "ansible/files/$SNAPSHOT" \
  root@$VAULT_IP:/tmp/vault-snapshot.snap

vault_exec "export VAULT_TOKEN=$TEMP_TOKEN; vault operator raft snapshot restore -force /tmp/vault-snapshot.snap"

# --- 6. Unseal avec les clés D'ORIGINE ---
echo -e "${GREEN}[6/6] Déverrouillage avec les clés d'origine${NC}"
sleep 5
vault_exec "vault operator unseal $VAULT_UNSEAL_1"
vault_exec "vault operator unseal $VAULT_UNSEAL_2"
vault_exec "vault operator unseal $VAULT_UNSEAL_3"

# --- Vérification ---
echo -e "${GREEN}=== Vérification des secrets ===${NC}"
vault_exec "export VAULT_TOKEN=$VAULT_ROOT_TOKEN; vault kv list secret/"

echo -e "${GREEN}=== Vault restauré et opérationnel ===${NC}"
echo -e "${GREEN}Interface : http://$VAULT_IP:8200${NC}"
