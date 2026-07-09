# --- AUTHENTIFICATION HASHICORP VAULT ---
# Identifiants AppRole requis pour permettre à Terraform de s'authentifier auprès de Vault.
variable "vault_role_id" {
  type = string
}
variable "vault_secret_id" {
  type      = string
  sensitive = true # Masqué dans la console pour protéger la clé secrète d'authentification
}

# --- PARAMÈTRES DU NOEUD & TEMPLATE ---
# Ciblage du serveur Proxmox ("pve") et sélection de l'image template Ubuntu 24.04 pour le conteneur.
variable "proxmox_node" {
  type    = string
  default = "pve"
}
variable "lxc_template" {
  type    = string
  default = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}

# --- IDENTIFICATION DE LA VM ---
# ID unique attribué au conteneur MariaDB dans l'inventaire Proxmox (par défaut : 135).
variable "mariadb_vm_id" {
  type    = number
  default = 135
}

# --- CONFIGURATION RÉSEAU ---
# Adresse IP statique du conteneur MariaDB avec son masque (/24) et sa passerelle par défaut (Gateway).
variable "mariadb_ip" {
  type    = string
  default = "192.168.50.6/24"
}
variable "mariadb_gateway" {
  type    = string
  default = "192.168.50.254"
}
