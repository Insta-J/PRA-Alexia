variable "vault_role_id" {
  type = string
}
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
  default = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}
variable "mariadb_vm_id" {
  type    = number
  default = 135
}
variable "mariadb_ip" {
  type    = string
  default = "192.168.50.6/24"
}
variable "mariadb_gateway" {
  type    = string
  default = "192.168.50.254"
}
