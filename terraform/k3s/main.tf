# 1. THE DISK RESIZE SNIPPET
# This is stored on your 2TB SSD (sre-data) and fixes the 2GB partition limit
resource "proxmox_virtual_environment_file" "k3s_disk_resize" {
  content_type = "snippets"
  datastore_id = "sre-data"
  node_name    = "pve"

  source_raw {
    data = <<EOF
#cloud-config
growpart:
  mode: auto
  devices: ['/']
  ignore_growpart_uses_gpt: true
resize_fs: /
EOF
    file_name = "k3s-resize.yaml"
  }
}

# 2. THE K3S NODES (201, 202, 203)
resource "proxmox_virtual_environment_vm" "k3s_nodes" {
  count     = 3
  name      = "k3s-node-${count.index}"
  node_name = "pve"
  vm_id     = 201 + count.index
  tags      = ["k3s", "srelab"]

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  agent {
    enabled = true
  }

  # This uses your 2TB SSD for the OS disk
  disk {
    datastore_id = "sre-data"
    interface    = "scsi0" # Matches your Template screenshot
    size         = 20
    ssd          = true
    discard      = "on"
  }

  initialization {
    datastore_id = "sre-data"
    
    # Move Cloud-Init drive to scsi3 to avoid IDE issues on newer kernels
    interface = "scsi3"

    ip_config {
      ipv4 {
        address = "192.168.178.${201 + count.index}/24"
        gateway = "192.168.178.1"
      }
    }

    # Use the snippet we defined above
    vendor_data_file_id = proxmox_virtual_environment_file.k3s_disk_resize.id

    user_account {
      username = "sre-admin"
      keys     = [var.ssh_public_key]
    }
  }

  network_device {
    bridge = "vmbr0"
  }

  # Helps the provider identify the OS type correctly
  operating_system {
    type = "l26"
  }
}

# This output makes it easy to update your Ansible hosts.ini later
output "k3s_node_ips" {
  value = [for vm in proxmox_virtual_environment_vm.k3s_nodes : vm.initialization[0].ip_config[0].ipv4[0].address]
}
