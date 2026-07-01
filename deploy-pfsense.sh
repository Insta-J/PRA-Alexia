#!/bin/bash
set -e

echo "=== Déploiement pfSense (token local) ==="
source .env   # charge TF_VAR_proxmox_token

cd terraform/pfsense
terraform init
terraform apply -auto-approve
cd ../..

echo "=== Injection config pfSense ==="
ansible-playbook -i ansible/inventory-pfsense.ini ansible/inject-pfsense.yml
