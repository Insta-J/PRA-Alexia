resource "proxmox_virtual_environment_container" "nagios" {
  node_name = var.proxmox_node
  vm_id     = var.nagios_vm_id

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
      # Mot de passe depuis Vault
      password = data.vault_kv_secret_v2.nagios.data["root_password"]
    }
  }

  operating_system {
    template_file_id = var.lxc_template
    type             = "ubuntu"
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "NAS"
    size         = 40
  }

  network_interface {
    name   = "eth0"
    bridge = "Vlan50"
  }

  features {
    nesting = true
  }

  started      = true
  unprivileged = true
}

output "nagios_ip" {
  value = var.nagios_ip
}
