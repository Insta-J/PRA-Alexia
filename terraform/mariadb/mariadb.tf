# --- CONFIGURATION PRINCIPALE DU CONTENEUR (LXC) ---
# Création du conteneur destiné à la base de données MariaDB sur le nœud et l'ID indiqués.
resource "proxmox_virtual_environment_container" "mariadb" {
  node_name = var.proxmox_node
  vm_id     = var.mariadb_vm_id

  # --- INITIALISATION & CONFIGURATION SYSTÈME ---
  # Définition du nom d'hôte, des serveurs DNS, de l'adressage IP statique et récupération du mot de passe root via Vault.
  initialization {
    hostname = "mariadb"
    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }
    ip_config {
      ipv4 {
        address = var.mariadb_ip
        gateway = var.mariadb_gateway
      }
    }
    user_account {
      # Récupération sécurisée du mot de passe root pour l'accès au système de l'appareil
      password = data.vault_kv_secret_v2.mariadb.data["root_lxc_password"]
    }
  }

  # --- SYSTÈME D'EXPLOITATION ---
  # Utilisation du template Ubuntu configuré pour initialiser le système.
  operating_system {
    template_file_id = var.lxc_template
    type              = "ubuntu"
  }

  # --- RESSOURCES (CPU & RAM) ---
  # Allocation standard et adaptée de 2 cœurs vCPU et 2 Go de RAM pour faire tourner la base MariaDB.
  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  # --- STOCKAGE (DISQUE) ---
  # Allocation d'un espace de 20 Go hébergé de manière centralisée sur le datastore "NAS".
  disk {
    datastore_id = "NAS"
    size         = 20
  }

  # --- INTERFACE RÉSEAU ---
  # Liaison de l'interface "eth0" sur le "Vlan50" dédié au réseau de management et d'administration.
  network_interface {
    name   = "eth0"
    bridge = "Vlan50"
  }

  # --- FONCTIONNALITÉS AVANCÉES ---
  # Activation du mode imbriqué (nesting), requis pour isoler certains moteurs de bases de données ou scripts au sein du LXC.
  features {
    nesting = true
  }

  # --- SÉCURITÉ & ÉTAT ---
  # Lancement automatique de la ressource à la fin de la tâche et isolation en mode non-privilégié.
  started      = true
  unprivileged = true
}

# --- AFFICHAGE DES DONNÉES (OUTPUT) ---
# Renvoie l'IP réseau fixe associée au serveur MariaDB.
output "mariadb_ip" {
  value = var.mariadb_ip
}
