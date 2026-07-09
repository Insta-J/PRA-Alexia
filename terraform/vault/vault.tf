# --- CONFIGURATION PRINCIPALE DU CONTENEUR (LXC) ---
# Définition de la ressource pour créer le conteneur HashiCorp Vault sur le nœud et l'ID spécifiés.
resource "proxmox_virtual_environment_container" "vault" {
  node_name = var.proxmox_node
  vm_id     = var.vault_vm_id

  # --- INITIALISATION & CONFIGURATION SYSTÈME ---
  # Définition du nom d'hôte (hostname), des DNS (Google/Cloudflare), de l'IP statique (avec sa passerelle) et du mot de passe root.
  initialization {
    hostname = "Vault"

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = var.vault_ip
        gateway = var.vault_gateway
      }
    }

    user_account {
      password = var.vault_root_password
    }
  }

  # --- SYSTÈME D'EXPLOITATION ---
  # Spécifie l'image template (.tar.zst) à utiliser pour installer l'OS (ici une base Ubuntu).
  operating_system {
    template_file_id = var.lxc_template
    type              = "ubuntu"
  }

  # --- RESSOURCES (CPU & RAM) ---
  # Allocation de 2 cœurs vCPU et de 2 Go de RAM dédiés au conteneur.
  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  # --- STOCKAGE (DISQUE) ---
  # Création d'un disque de 20 Go stocké sur le datastore nommé "NAS".
  disk {
    datastore_id = "NAS"
    size         = 20
  }

  # --- INTERFACE RÉSEAU ---
  # Configuration de l'interface "eth0" reliée directement au "Vlan50" de Proxmox.
  network_interface {
    name   = "eth0"
    bridge = "Vlan50"
  }

  # --- FONCTIONNALITÉS AVANCÉES ---
  # Active le "nesting" (imbrication), souvent indispensable pour faire tourner Docker ou des services spécifiques dans le LXC.
  features {
    nesting = true
  }

  # --- SÉCURITÉ & ÉTAT ---
  # Démarre automatiquement le LXC à la fin du déploiement et l'exécute en mode non-privilégié (bonne pratique de sécurité).
  started      = true
  unprivileged = true
}

# --- AFFICHAGE DES DONNÉES (OUTPUT) ---
# Renvoie l'adresse IP statique attribuée au conteneur Vault.
output "vault_ip" {
  value = var.vault_ip
}
