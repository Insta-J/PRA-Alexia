# --- AUTHENTIFICATION HASHICORP VAULT ---
# Identifiants AppRole requis pour authentifier Terraform auprès de ton coffre-fort Vault.
variable "vault_role_id" { type = string }
variable "vault_secret_id" {
  type      = string
  sensitive = true # Masqué dans la console pour protéger le secret d'authentification
}

# --- PARAMÈTRES DU NOEUD & TEMPLATE ---
# Définition du serveur Proxmox cible ("pve") et du template d'OS Ubuntu pour le conteneur.
variable "proxmox_node" {
  type    = string
  default = "pve"
}
variable "lxc_template" {
  type    = string
  default = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

# --- IDENTIFICATION DE LA VM ---
# ID unique attribué au conteneur Nextcloud dans Proxmox (par défaut : 133).
variable "nextcloud_vm_id" {
  type    = number
  default = 133
}

# --- CONFIGURATION RÉSEAU (VLAN 40) ---
# Adresse IP statique du conteneur Nextcloud avec son masque (/24) et sa passerelle par défaut (Gateway).
variable "nextcloud_ip" {
  type    = string
  default = "192.168.40.50/24"
}
variable "nextcloud_gateway" {
  type    = string
  default = "192.168.40.254"
}
