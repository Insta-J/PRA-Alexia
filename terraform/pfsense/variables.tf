# --- ACCÈS API PROXMOX ---
# URL de l'API Proxmox (ex: https://192.168.1.10:8006/api2/json)
variable "proxmox_url" {
  type = string
}

# Token d'authentification Proxmox (clé API) masqué dans les logs pour la sécurité
variable "proxmox_token" {
  type      = string
  sensitive = true
}

# --- PARAMÈTRES DU NOEUD ---
# Nom du serveur physique Proxmox où déployer la VM (par défaut : "pve")
variable "proxmox_node" {
  type    = string
  default = "pve"
}

# --- CONFIGURATION DE LA VM PFSENSE ---
# ID du template pfSense existant qui servira de base pour le clonage (par défaut : 114)
variable "pfsense_template_id" {
  type    = number
  default = 114
}

# ID unique qui sera attribué à la nouvelle VM pfSense (par défaut : 130)
variable "pfsense_vm_id" {
  type    = number
  default = 130
}
