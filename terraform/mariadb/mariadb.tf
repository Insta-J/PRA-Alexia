resource "proxmox_virtual_environment_container" "mariadb" {
  node_name = var.proxmox_node
  vm_id     = var.mariadb_vm_id

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
      password = data.vault_kv_secret_v2.mariadb.data["root_lxc_password"]
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
    dedicated = 2048
  }

  disk {
    datastore_id = "NAS"
    size         = 20
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

output "mariadb_ip" {
  value = var.mariadb_ip
}
