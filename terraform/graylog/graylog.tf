resource "proxmox_virtual_environment_container" "graylog" {
  node_name = var.proxmox_node
  vm_id     = var.graylog_vm_id

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
      password = data.vault_kv_secret_v2.graylog.data["root_lxc_password"]
    }
  }

  operating_system {
    template_file_id = var.lxc_template
    type             = "ubuntu"
  }

  cpu    { cores = 4 }
  memory { dedicated = 16384 }   # OpenSearch gourmand

  disk {
    datastore_id = "NAS"
    size         = 60
  }

  network_interface {
    name   = "eth0"
    bridge = "Vlan50"
  }

  features { nesting = true }

  started      = true
  unprivileged = true
}

output "graylog_ip" { value = var.graylog_ip }
