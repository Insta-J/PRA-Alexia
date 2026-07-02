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
  address = "http://192.168.30.1:8200"
}

data "vault_kv_secret_v2" "proxmox" {
  mount = "secret"
  name  = "proxmox"
}

provider "proxmox" {
  endpoint  = data.vault_kv_secret_v2.proxmox.data["api_url"]
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = true
}
