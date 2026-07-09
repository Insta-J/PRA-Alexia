# --- CONFIGURATION PRINCIPALE DU CONTENEUR (LXC) ---
# Création du conteneur pour Nagios XI sur le nœud Proxmox et l'ID spécifiés.
resource "proxmox_virtual_environment_container" "nagios" {
  node_name = var.proxmox_node
  vm_id     = var.nagios_vm_id

  # --- INITIALISATION & CONFIGURATION SYSTÈME ---
  # Définition du hostname, des serveurs DNS, de l'IP statique (avec sa gateway) et récupération sécurisée du mot de passe root.
  initialization {
    hostname = "nagiosxi"

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = var.nagios_ip
        gateway = var.nagios_gateway
      }
    }

    user_account {
      # Récupération dynamique et sécurisée du mot de passe root depuis le coffre-fort HashiCorp Vault
      password = data.vault_kv_secret_v2.nagios.data["root_password"]
    }
  }

  # --- SYSTÈME D'EXPLOITATION ---
  # Spécifie le template d'image Ubuntu à déployer pour le conteneur Nagios.
  operating_system {
    template_file_id = var.lxc_template
    type              = "ubuntu"
  }

  # --- RESSOURCES (CPU & RAM) ---
  # Allocation de 2 cœurs vCPU et de 4 Go (4096 Mo) de RAM dédiée (Nagios XI est un peu plus gourmand).
  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  # --- STOCKAGE (DISQUE) ---
  # Création d'un disque de 40 Go hébergé sur le datastore "NAS" (pour stocker les logs et l'historique de supervision).
  disk {
    datastore_id = "NAS"
    size         = 40
  }

  # --- INTERFACE RÉSEAU ---
  # Configuration de l'interface "eth0" connectée sur le "Vlan50" (le réseau d'administration).
  network_interface {
    name   = "eth0"
    bridge = "Vlan50"
  }

  # --- FONCTIONNALITÉS AVANCÉES ---
  # Active le nesting (imbrication), pratique si Nagios a besoin de lancer des sous-conteneurs ou des runtimes spécifiques.
  features {
    nesting = true
  }

  # --- SÉCURITÉ & ÉTAT ---
  # Démarrage automatique après création et exécution en mode non-privilégié pour la sécurité du serveur hôte.
  started      = true
  unprivileged = true
}

# --- AFFICHAGE DES DONNÉES (OUTPUT) ---
# Renvoie l'adresse IP statique utilisée pour joindre l'interface de supervision Nagios.
output "nagios_ip" {
  value = var.nagios_ip
}
