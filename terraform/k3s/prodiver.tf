terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.1" # Modern 2026 version
    }
  }
}

provider "proxmox" {
  endpoint = "${var.proxmox_machine_host}:8006/"
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure = true 
  ssh {
    agent = true
    username = "root"
  }
}
