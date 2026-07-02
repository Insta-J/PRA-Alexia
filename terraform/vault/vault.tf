resource "proxmox_virtual_environment_container" "vault" {
  node_name = var.proxmox_node
  vm_id     = var.vault_vm_id

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

output "vault_ip" {
  value = var.vault_ip
}
