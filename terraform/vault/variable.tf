variable "proxmox_url" { type = string }
variable "proxmox_token" {
  type      = string
  sensitive = true
}
variable "proxmox_node" {
  type    = string
  default = "pve"
}
variable "lxc_template" {
  type    = string
  default = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}
variable "vault_vm_id" {
  type    = number
  default = 131
}
variable "vault_ip" {
  type    = string
  default = "192.168.50.4/24"
}
variable "vault_gateway" {
  type    = string
  default = "192.168.50.254"
}
variable "vault_root_password" {
  description = "Mot de passe root du LXC Vault"
  type        = string
  sensitive   = true
}
