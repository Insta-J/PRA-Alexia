# --- EXIGENCES TERRAFORM & PROVIDERS ---
# Définition des dépendances : on spécifie ici qu'on utilise le provider Proxmox officiel de la communauté (bpg/proxmox) en version 0.46.x.
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
  }
}

# --- CONFIGURATION DU PROVIDER PROXMOX ---
# Connexion à l'API Proxmox en utilisant les variables de sécurité. 
# "insecure = true" permet d'ignorer les alertes de certificat SSL auto-signé.
provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_token
  insecure  = true
}
