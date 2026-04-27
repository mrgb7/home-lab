variable "proxmox_api_token_id" {
  type        = string
  description = "The ID of the Proxmox API token (e.g., root@pam!terraform)"
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "The secret part of the Proxmox API token"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "Your public SSH key for VM access"
}
