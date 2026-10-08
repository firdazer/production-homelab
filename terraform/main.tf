locals {
  k3s_nodes = {
    "k3s-cp01" = {
      vm_id  = 201
      cores  = 2
      memory = 2048
      ip     = "192.168.100.31"
    }

    "k3s-w01" = {
      vm_id  = 202
      cores  = 4
      memory = 5120
      ip     = "192.168.100.32"
    }
  }
}

resource "proxmox_virtual_environment_vm" "k3s" {
  for_each = local.k3s_nodes

  name        = each.key
  description = "Production-inspired homelab K3s node"
  tags        = ["terraform", "k3s"]

  node_name = "pve01"
  vm_id     = each.value.vm_id

  clone {
    vm_id = 9000
    full  = true
  }

  # Guest agent is installed by Ansible after initial provisioning.
  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "192.168.100.1"
      }
    }

    dns {
      servers = ["192.168.100.1"]
    }

    user_account {
      username = "firdazer"
      keys = [
        trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
      ]
    }
  }
}
