resource "proxmox_virtual_environment_container" "nextcloud" {
  node_name = var.proxmox_node
  vm_id     = var.nextcloud_vm_id

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
      password = data.vault_kv_secret_v2.nextcloud.data["root_password"]
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
    size         = 30
  }

  network_interface {
    name   = "eth0"
    bridge = "Vlan40"
  }

  features {
    nesting = true
  }

  started      = true
  unprivileged = true
}

output "nextcloud_ip" {
  value = var.nextcloud_ip
}
