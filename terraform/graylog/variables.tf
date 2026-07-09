# --- AUTHENTIFICATION HASHICORP VAULT ---
# Identifiants AppRole requis pour authentifier Terraform auprès de ton coffre-fort Vault.
variable "vault_role_id" {
  type = string
}

variable "vault_secret_id" {
  type      = string
  sensitive = true # Masqué dans la console pour protéger le secret d'authentification
}

# --- PARAMÈTRES DU NOEUD & TEMPLATE ---
# Définition du serveur Proxmox cible ("pve") et du template LXC (ici mis à jour en Ubuntu 24.04).
variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "lxc_template" {
  type    = string
  default = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}

# --- IDENTIFICATION DE LA VM ---
# ID unique attribué au conteneur Graylog dans Proxmox (par défaut : 134).
variable "graylog_vm_id" {
  type    = number
  default = 134
}

# --- CONFIGURATION RÉSEAU ---
# Adresse IP statique du conteneur avec son masque (/24) et sa passerelle par défaut (Gateway).
variable "graylog_ip" {
  type    = string
  default = "192.168.50.2/24"
}

variable "graylog_gateway" {
  type    = string
  default = "192.168.50.254"
}
