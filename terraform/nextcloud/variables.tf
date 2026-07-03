variable "vault_role_id" { type = string }
variable "vault_secret_id" {
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
variable "nextcloud_vm_id" {
  type    = number
  default = 133
}
variable "nextcloud_ip" {
  type    = string
  default = "192.168.40.50/24"
}
variable "nextcloud_gateway" {
  type    = string
  default = "192.168.40.254"
}
