# --- ACCÈS API PROXMOX ---
# URL de l'API Proxmox et Token d'authentification sécurisé (masqué dans les logs).
variable "proxmox_url" { type = string }
variable "proxmox_token" {
  type      = string
  sensitive = true
}

# --- PARAMÈTRES DU NOEUD & TEMPLATE ---
# Nœud Proxmox cible ("pve") et chemin vers le template d'OS Ubuntu pour le LXC.
variable "proxmox_node" {
  type    = string
  default = "pve"
}
variable "lxc_template" {
  type    = string
  default = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

# --- IDENTIFICATION DE LA VM ---
# ID unique attribué au conteneur Vault dans Proxmox (par défaut : 131).
variable "vault_vm_id" {
  type    = number
  default = 131
}

# --- CONFIGURATION RÉSEAU ---
# Adresse IP statique avec son masque CIDR (/24) et la passerelle de secours (Gateway).
variable "vault_ip" {
  type    = string
  default = "192.168.50.4/24"
}
variable "vault_gateway" {
  type    = string
  default = "192.168.50.254"
}

# --- SÉCURITÉ INVITÉ ---
# Mot de passe du compte root du conteneur, marqué comme sensible pour protéger sa valeur.
variable "vault_root_password" {
  description = "Mot de passe root du LXC Vault"
  type        = string
  sensitive   = true
}
