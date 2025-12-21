variable "prefix" {
  type    = string
  default = "portfolio"
}

variable "location" {
  type    = string
  default = "eastus" # change to preferred region
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

# Path to the public SSH key file (use the public key you generated)
variable "ssh_pub_key" {
  type    = string
}

variable "ssh_pri_key" {
  type    = string
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s" # recommended for Jenkins controller
}

variable "vm_name" {
  type    = string
  default = "jenkins-vm"
}

variable "key_vault_name" {
  type    = string
  default = "" # optional; otherwise terraform will set automatically
}

variable "vault_secret_name" {
  type    = string 
}

variable "github_oidc_client_id" {
  description = "Client ID of existing GitHub OIDC App Registration"
  type        = string
}
