# --- CONFIGURATION PRINCIPALE DU CONTENEUR (LXC) ---
# Création du conteneur destiné à Nextcloud sur le nœud et l'ID Proxmox indiqués.
resource "proxmox_virtual_environment_container" "nextcloud" {
  node_name = var.proxmox_node
  vm_id     = var.nextcloud_vm_id

  # --- INITIALISATION & CONFIGURATION SYSTÈME ---
  # Définition du nom d'hôte, des serveurs DNS, de l'IP statique et récupération sécurisée du mot de passe root via Vault.
  initialization {
    hostname = "nextcloud"

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = var.nextcloud_ip
        gateway = var.nextcloud_gateway
      }
    }

    user_account {
      # Récupération sécurisée du mot de passe root pour l'accès au conteneur Nextcloud
      password = data.vault_kv_secret_v2.nextcloud.data["root_password"]
    }
  }

  # --- SYSTÈME D'EXPLOITATION ---
  # Utilisation du template Ubuntu configuré pour initialiser le conteneur.
  operating_system {
    template_file_id = var.lxc_template
    type              = "ubuntu"
  }

  # --- RESSOURCES (CPU & RAM) ---
  # Allocation standard et adaptée de 2 cœurs vCPU et 2 Go de RAM pour Nextcloud.
  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  # --- STOCKAGE (DISQUE) ---
  # Allocation d'un espace disque de 30 Go stocké de manière centralisée sur le datastore "NAS".
  disk {
    datastore_id = "NAS"
    size         = 30
  }

  # --- INTERFACE RÉSEAU ---
  # Liaison de l'interface "eth0" sur le "Vlan40" (le réseau dédié aux données ou utilisateurs).
  network_interface {
    name   = "eth0"
    bridge = "Vlan40"
  }

  # --- FONCTIONNALITÉS AVANCÉES ---
  # Activation du mode imbriqué (nesting), indispensable pour l'exécution fluide de certains sous-processus web de Nextcloud.
  features {
    nesting = true
  }

  # --- SÉCURITÉ & ÉTAT ---
  # Lancement automatique à la fin du déploiement et isolation en mode non-privilégié.
  started      = true
  unprivileged = true
}

# --- AFFICHAGE DES DONNÉES (OUTPUT) ---
# Renvoie l'IP réseau fixe associée au serveur Nextcloud.
output "nextcloud_ip" {
  value = var.nextcloud_ip
}
