variable "proxmox_url" {
  type = string
}
variable "proxmox_token" {
  type      = string
  sensitive = true
}
variable "proxmox_node" {
  type    = string
  default = "pve"
}
variable "pfsense_template_id" {
  type    = number
  default = 114
}
variable "pfsense_vm_id" {
  type    = number
  default = 130
}
