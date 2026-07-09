#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Déploiement pfSense — PRA Alexia ===${NC}"

[ -f .env ] || { echo -e "${RED}.env introuvable${NC}"; exit 1; }
[ -f ansible/files/config-pfsense.xml ] || { echo -e "${RED}config.xml introuvable${NC}"; exit 1; }

echo -e "${GREEN}[1/4] Chargement des variables${NC}"
source .env

echo -e "${GREEN}[2/4] Clonage du template (Terraform)${NC}"
cd terraform/pfsense
terraform init -input=false
terraform apply -auto-approve

#  Détection de l'IP WAN via l'agent QEMU
echo -e "${GREEN}[3/4] Détection de l'IP WAN de pfSense${NC}"
PFSENSE_IP=""
for i in $(seq 1 30); do
  terraform refresh >/dev/null 2>&1
  PFSENSE_IP=$(terraform output -raw pfsense_ip 2>/dev/null || echo "")
  if [[ "$PFSENSE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${GREEN}IP WAN détectée : $PFSENSE_IP${NC}"
    break
  fi
  echo -e "${YELLOW}Attente de l'IP $i/30...${NC}"
  sleep 10
done
cd ../..

if [[ ! "$PFSENSE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "${RED}IP non détectée. Vérifiez l'agent QEMU dans pfSense.${NC}"
  exit 1
fi

# Attendre que SSH soit ouvert
echo -e "${GREEN}Attente du port SSH sur $PFSENSE_IP${NC}"
for i in $(seq 1 20); do
  if nc -z -w 2 "$PFSENSE_IP" 22 >/dev/null 2>&1; then
    echo -e "${GREEN}SSH prêt${NC}"
    sleep 5
    break
  fi
  echo -e "${YELLOW}SSH $i/20...${NC}"
  sleep 5
done

echo -e "${GREEN}[4/4] Injection de la configuration (Ansible)${NC}"
ansible-playbook -i ansible/inventory-pfsense.ini ansible/inject-pfsense.yml \
  --extra-vars "ansible_host=$PFSENSE_IP"

echo -e "${GREEN}=== pfSense déployé (WAN: $PFSENSE_IP → config appliquée) ===${NC}"
