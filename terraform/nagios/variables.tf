variable "vault_role_id" {
  description = "AppRole Role ID"
  type        = string
}

variable "vault_secret_id" {
  description = "AppRole Secret ID"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "lxc_template" {
  type    = string
  default = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

variable "nagios_vm_id" {
  type    = number
  default = 132
}

variable "nagios_ip" {
  type    = string
  default = "192.168.50.3/24"
}

variable "nagios_gateway" {
  type    = string
  default = "192.168.50.254"
}
