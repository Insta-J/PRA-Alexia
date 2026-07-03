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

data "vault_kv_secret_v2" "proxmox" {
  mount = "kv"
  name  = "proxmox"
}

data "vault_kv_secret_v2" "nextcloud" {
  mount = "kv"
  name  = "nextcloud"
}

provider "proxmox" {
  endpoint  = data.vault_kv_secret_v2.proxmox.data["api_url"]
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = true
}
