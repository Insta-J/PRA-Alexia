# --- EXIGENCES TERRAFORM & PROVIDERS ---
# Déclaration du provider Proxmox (bpg/proxmox) requis pour ce module et verrouillage de la version.
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
  }
}

# --- CONFIGURATION DU PROVIDER PROXMOX ---
# Initialisation de la connexion à l'API Proxmox avec désactivation de la vérification SSL (insecure).
provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_token
  insecure  = true
}
