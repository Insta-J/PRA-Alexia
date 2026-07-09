# --- CONFIGURATION PRINCIPALE DU CONTENEUR (LXC) ---
# Création du conteneur pour la pile Graylog sur le nœud Proxmox et l'ID spécifiés.
resource "proxmox_virtual_environment_container" "graylog" {
  node_name = var.proxmox_node
  vm_id     = var.graylog_vm_id

  # --- INITIALISATION & CONFIGURATION SYSTÈME ---
  # Définition du hostname, des serveurs DNS, de l'IP statique (avec sa gateway) et extraction sécurisée du mot de passe root depuis Vault.
  initialization {
    hostname = "graylog"
    dns { servers = ["8.8.8.8", "1.1.1.1"] }
    ip_config {
      ipv4 {
        address = var.graylog_ip
        gateway = var.graylog_gateway
      }
    }
    user_account {
      # Récupération sécurisée du mot de passe root LXC depuis Vault
      password = data.vault_kv_secret_v2.graylog.data["root_lxc_password"]
    }
  }

  # --- SYSTÈME D'EXPLOITATION ---
  # Déploiement d'un OS basé sur le template Ubuntu configuré.
  operating_system {
    template_file_id = var.lxc_template
    type              = "ubuntu"
  }

  # --- RESSOURCES (CPU & RAM) ---
  # Allocation importante de 4 cœurs vCPU et 16 Go (16384 Mo) de RAM.
  # Nécessaire pour faire tourner Graylog, MongoDB et surtout la pile OpenSearch/Elasticsearch qui est très gourmande.
  cpu    { cores = 4 }
  memory { dedicated = 16384 }

  # --- STOCKAGE (DISQUE) ---
  # Création d'un disque de 60 Go sur le datastore "NAS" pour accueillir l'indexation des logs.
  disk {
    datastore_id = "NAS"
    size         = 60
  }

  # --- INTERFACE RÉSEAU ---
  # Connexion de l'interface par défaut "eth0" sur le "Vlan50" (réseau d'administration).
  network_interface {
    name   = "eth0"
    bridge = "Vlan50"
  }

  # --- FONCTIONNALITÉS AVANCÉES ---
  # Active le nesting (imbrication), indispensable pour le bon fonctionnement des bases de données et des runtimes du LXC.
  features { nesting = true }

  # --- SÉCURITÉ & ÉTAT ---
  # Automatisation du démarrage après déploiement et isolation renforcée en mode non-privilégié.
  started      = true
  unprivileged = true
}

# --- AFFICHAGE DES DONNÉES (OUTPUT) ---
# Renvoie l'adresse IP statique permettant d'accéder au serveur et à l'interface web de Graylog.
output "graylog_ip" { value = var.graylog_ip }
