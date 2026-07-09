# --- AUTHENTIFICATION HASHICORP VAULT ---
# Identifiants de la méthode d'authentification AppRole pour permettre à Terraform d'accéder au coffre-fort.
variable "vault_role_id" {
  description = "AppRole Role ID"
  type        = string
}

variable "vault_secret_id" {
  description = "AppRole Secret ID"
  type        = string
  sensitive   = true # Masqué dans la console pour protéger le secret
}

# --- PARAMÈTRES DU NOEUD & TEMPLATE ---
# Ciblage du nœud Proxmox ("pve") et sélection du template d'image Ubuntu pour le LXC.
variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "lxc_template" {
  type    = string
  default = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

# --- IDENTIFICATION DE LA VM ---
# ID unique qui sera affecté au conteneur Nagios XI (par défaut : 132).
variable "nagios_vm_id" {
  type    = number
  default = 132
}

# --- CONFIGURATION RÉSEAU ---
# Adresse IP fixe avec son masque (/24) et passerelle par défaut (Gateway).
variable "nagios_ip" {
  type    = string
  default = "192.168.50.3/24"
}

variable "nagios_gateway" {
  type    = string
  default = "192.168.50.254"
}
