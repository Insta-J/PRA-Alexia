resource "proxmox_virtual_environment_vm" "pfsense" {
  name        = "vm-pfsense"
  description = "Firewall pfSense - Site primaire"
  node_name   = var.proxmox_node
  vm_id       = var.pfsense_vm_id

  clone {
    vm_id = var.pfsense_template_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

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

  operating_system {
    type = "other"
  }

  started = true

  lifecycle {
    ignore_changes = [network_device]
  }
}

output "pfsense_vm_id" {
  value = proxmox_virtual_environment_vm.pfsense.vm_id
} 
