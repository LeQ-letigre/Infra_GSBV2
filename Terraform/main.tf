# génération de la clé SSH pour les conteneurs LXC
resource "tls_private_key" "lxc_ssh_key" {
  for_each = var.lxc_linux
  algorithm = "ED25519"
}

# Enregistrement de la clé privée SSH dans un fichier local
resource "local_file" "private_key" {

  for_each = var.lxc_linux

 content  = tls_private_key.lxc_ssh_key[each.key].private_key_openssh
 filename = pathexpand("~/.ssh/${each.value.name}-ed25519")
 file_permission = "0600"
}

# Création des conteneurs LXC avec les configurations définies dans la variable lxc_linux
resource "proxmox_virtual_environment_container" "lxc_linux" {

  for_each = var.lxc_linux

  node_name = var.target_node
  vm_id     = each.value.lxc_id

  initialization {
    hostname = each.value.name

    user_account {
      password = "Formation13@"
      keys     = [tls_private_key.lxc_ssh_key[each.key].public_key_openssh]
    }

    ip_config {
      ipv4 {
        address = each.value.ipconfig0
        gateway = each.value.gw
      }
    }

    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }
  }

  operating_system {
    template_file_id = var.chemin_cttemplate
    type            = "debian"
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = "local-lvm"
    size         = each.value.disk_size
  }

  network_interface {
    name    = "eth0"
    bridge  = each.value.network_bridge
    enabled = true
  }

  features {
    nesting = true
  }

  started     = true
  unprivileged = true
}

resource "proxmox_virtual_environment_vm" "winsrv" {

  for_each = var.win_srv

  name        = each.value.name
  vm_id       = each.value.vmid
  node_name   = var.target_node

  clone {
    vm_id = "2000"
    full  = true
  }

  started = true
  on_boot = true

  agent {
    enabled = true
    timeout = "300s"
  }

  bios = "ovmf"

  scsi_hardware = "virtio-scsi-single"

  boot_order = ["scsi0", "ide1"]

  cpu {
    cores   = 6
    sockets = 1
  }

  memory {
    dedicated = 6144
  }

  # Disque principal SCSI
  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm"
    size         = 40
    cache        = "writeback"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  serial_device {}

  initialization {
    ip_config {
      ipv4 {
        address = each.value.ipconfig0
        gateway = each.value.gw
      }
    }

    dns {
      servers = [each.value.dns]
    }

    user_account {
      username = "Administrateur"
      password = "Formation13@"
    }
  }
}

# resource "proxmox_virtual_environment_vm" "opnsenses" {

#   for_each = var.opnsenses

#   name        = each.value.name
#   vm_id       = each.value.vmid
#   node_name   = var.target_node

#   clone {
#     vm_id = each.value.clone_id
#     full  = true
#   }

#   started = true
#   on_boot = true

#   agent {
#     enabled = true
#     timeout = "300s"
#   }

#   bios = "seabios"

#   scsi_hardware = "virtio-scsi-single"

#   boot_order = ["scsi0", "ide1"]

#   cpu {
#     cores   = 2
#     sockets = 1
#   }

#   memory {
#     dedicated = 2048
#   }

#   # Disque principal SCSI
#   disk {
#     interface    = "scsi0"
#     datastore_id = "local-lvm"
#     size         = 10
#     cache        = "writeback"
#   }

#   network_device {
#     bridge = "vmbr0"
#     model  = "virtio"
#   }

#   network_device {
#     bridge  = "vmbr2"
#     model   = "virtio"
#     vlan_id = 150
#   }

#   network_device {
#     bridge = "Sync"
#     model  = "virtio"
#   }

#   network_device {
#     bridge = "vmbr2"
#     model  = "virtio"
#   }

#   serial_device {}

#   initialization {

#     user_account {
#       username = "root"
#       password = "Formation13@"
#     }
#   }
# }