# --- EXIGENCES TERRAFORM & PROVIDERS ---
# Déclaration et verrouillage des versions des deux providers requis : Proxmox (bpg) et Vault (HashiCorp).
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

# --- CONFIGURATION DU PROVIDER HASHICORP VAULT ---
# Connexion à l'instance Vault locale et authentification sécurisée via la méthode AppRole (Role ID + Secret ID).
provider "vault" {
  address          = "http://192.168.50.4:8200"
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# --- ÉLÉMENTS DE DONNÉES (DATA SOURCES VAULT) ---
# Récupération dynamique des secrets stockés dans le moteur de clés-valeurs (KV v2) de Vault pour Proxmox et Nagios.
data "vault_kv_secret_v2" "proxmox" {
  mount = "kv"
  name  = "proxmox"
}

data "vault_kv_secret_v2" "nagios" {
  mount = "kv"
  name  = "nagiosxi"
}

# --- CONFIGURATION DU PROVIDER PROXMOX ---
# Initialisation du provider Proxmox alimenté directement par les données (URL et Token) récupérées de manière sécurisée dans Vault.
provider "proxmox" {
  endpoint  = data.vault_kv_secret_v2.proxmox.data["api_url"]
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = true
}
