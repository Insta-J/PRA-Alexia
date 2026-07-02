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

# Provider Vault avec authentification AppRole
provider "vault" {
  address = "http://192.168.50.4:8200"
  skip_child_token = true


  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# Lire les secrets Proxmox depuis Vault
data "vault_kv_secret_v2" "proxmox" {
  mount = "kv"
  name  = "proxmox"
}

# Lire les secrets Nagios depuis Vault
data "vault_kv_secret_v2" "nagios" {
  mount = "kv"
  name  = "nagiosxi"
}

# Provider Proxmox alimenté par Vault
provider "proxmox" {
  endpoint  = data.vault_kv_secret_v2.proxmox.data["api_url"]
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = true
}
