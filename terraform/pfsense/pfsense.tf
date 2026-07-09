# --- CONFIGURATION PRINCIPALE DE LA VM ---
# Définition du nom, de la description, du nœud Proxmox cible et de l'ID de la VM.
resource "proxmox_virtual_environment_vm" "pfsense" {
  name        = "Pfsense-Axelia"
  description = "Firewall pfSense - Site primaire"
  node_name   = var.proxmox_node
  vm_id       = var.pfsense_vm_id

  # --- AGENT INVITÉ ---
  # Active l'agent QEMU pour permettre à Proxmox de remonter l'adresse IP de la VM.
  agent {
    enabled = true
  }

  # --- CLONAGE ---
  # Crée la VM en effectuant un clone complet (indépendant) à partir d'un template existant.
  clone {
    vm_id = var.pfsense_template_id
    full  = true
  }

  # --- RESSOURCES (CPU & RAM) ---
  # Allocation de 2 cœurs vCPU (type hôte pour de meilleures performances) et de 2 Go de RAM.
  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  # --- INTERFACES RÉSEAU ---
  # Déclaration des 5 cartes réseau VirtIO. 
  # L'ordre ici détermine leur attribution dans pfSense (vtnet0 à vtnet4).
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }
  network_device {
    bridge = "Vlan20"
    model  = "virtio"
  }
  network_device {
    bridge = "Vlan30"
    model  = "virtio"
  }
  network_device {
    bridge = "Vlan40"
    model  = "virtio"
  }
  network_device {
    bridge = "Vlan50"
    model  = "virtio"
  }

  # --- SYSTÈME & COMPORTEMENT ---
  # Type d'OS configuré sur "other" (adapté pour FreeBSD/pfSense) et démarrage auto de la VM.
  operating_system {
    type = "other"
  }

  started = true

  # --- CYCLE DE VIE ---
  # Ignore les modifications futures sur les cartes réseau pour éviter les conflits Terraform/Proxmox.
  lifecycle {
    ignore_changes = [network_device]
  }
}

# --- AFFICHAGES DES DONNÉES (OUTPUTS) ---
# Renvoie l'ID de la machine et son adresse IPv4 (WAN) dès qu'elle est détectée par l'agent.
output "pfsense_vm_id" {
  value = proxmox_virtual_environment_vm.pfsense.vm_id
}

# IP détectée via l'agent QEMU (interface WAN/DHCP)
output "pfsense_ip" {
  value = try(proxmox_virtual_environment_vm.pfsense.ipv4_addresses[0][0], "IP non détectée")
}
