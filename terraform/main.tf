resource "proxmox_virtual_environment_vm" "terraform_test" {
  name        = "terraform-test"
  description = "Disposable VM for validating Terraform provisioning"
  tags        = ["terraform", "test"]

  node_name = "pve01"
  vm_id     = 9100

  clone {
    vm_id = 9000
    full  = true
  }

  # QEMU Guest Agent will be installed later by Ansible.
  # Do not enable the agent here yet because the base template
  # intentionally does not contain qemu-guest-agent.
  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "firdazer"
      keys = [
        trimspace(file("~/.ssh/id_ed25519.pub"))
      ]
    }
  }
}
