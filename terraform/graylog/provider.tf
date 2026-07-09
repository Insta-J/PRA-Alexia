# --- EXIGENCES TERRAFORM & PROVIDERS ---
# Déclaration et verrouillage des versions pour les providers Proxmox (bpg) et Vault (HashiCorp).
terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox", version = "~> 0.46" }
    vault   = { source = "hashicorp/vault", version = "~> 4.0" }
  }
}

# --- CONFIGURATION DU PROVIDER HASHICORP VAULT ---
# Connexion à l'instance Vault et authentification sécurisée via la méthode AppRole.
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
# Récupération dynamique des secrets stockés dans le moteur KV (v2) pour Proxmox et Graylog.
data "vault_kv_secret_v2" "proxmox" {
  mount = "kv"
  name  = "proxmox"
}

data "vault_kv_secret_v2" "graylog" {
  mount = "kv"
  name  = "graylog"
}

# --- CONFIGURATION DU PROVIDER PROXMOX ---
# Initialisation du provider Proxmox avec l'URL de l'API et le token d'accès extraits en direct de Vault.
provider "proxmox" {
  endpoint  = data.vault_kv_secret_v2.proxmox.data["api_url"]
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = true
}
