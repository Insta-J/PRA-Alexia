variable "proxmox_node" {
  description = "Nom du nœud Proxmox"
  type        = string
  default     = "proxmox"
}

variable "pfsense_template_id" {
  description = "VM ID du template pfSense"
  type        = number
  default     = 114
}

variable "pfsense_vm_id" {
  description = "VM ID de la nouvelle VM pfSense"
  type        = number
  default     = 111
}
