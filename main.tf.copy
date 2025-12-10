# génération de la clé SSH pour les conteneurs LXC
resource "tls_private_key" "lxc_ssh_key" {
  for_each = var.lxc_linux
  algorithm = "ED25519"
}

# Enregistrement de la clé privée SSH dans un fichier local
resource "local_file" "private_key" {

  for_each = var.lxc_linux

 content  = tls_private_key.lxc_ssh_key[each.key].private_key_openssh
 filename = pathexpand("~/etc/ansible/keys/${each.value.name}")
 file_permission = "0600"
}

# Création des windows server 2019


# Création des conteneurs LXC avec les configurations définies dans la variable lxc_linux
resource "proxmox_lxc" "lxc_linux" {

  for_each = var.lxc_linux

  target_node      = var.target_node
  hostname         = each.value.name
  vmid             = each.value.lxc_id
  ostemplate       = var.chemin_cttemplate
  password         = "Formation13@"
  start            = true
  cores            = each.value.cores
  memory           = each.value.memory
  ssh_public_keys  = tls_private_key.lxc_ssh_key[each.key].public_key_openssh
  unprivileged     = true
  nameserver       = "1.1.1.1 8.8.8.8"

  rootfs {
    storage = "local-lvm"
    size    = each.value.disk_size
  }

  network {
   name     = "eth0"
   bridge   = each.value.network_bridge
   ip       = each.value.ipconfig0
   gw       = each.value.gw
   firewall = false
  }


  features {
    nesting = true
  }
}

resource "proxmox_vm_qemu" "winsrv" {

  for_each = var.win_srv

  name        = each.value.name
  vmid        = each.value.vmid

  clone       = "WinTemplate"
  full_clone  = true
  onboot      = true
  agent = 1
  agent_timeout = 300
  bios        = "ovmf"
  scsihw      = "virtio-scsi-single"
  boot        = "order=scsi0;ide1"
  target_node = var.target_node


  memory      = 6144

  cpu {
    cores   = 6
    sockets = 1
  }

  # Disque principal SCSI (slot = scsi0)
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = "local-lvm"
    size    = "40G"
    cache   = "writeback"
  }

  # Disque Cloud-Init (slot = ide2 ou scsi1 selon ta pratique)
  disk {
    slot    = "ide1"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  serial {
      id   = 0
      type = "socket"
    }

  ipconfig0  = each.value.ipconfig0
  nameserver = each.value.dns 
  ciuser     = "Administrateur"
  cipassword = "Formation13@"
}

# Clonage des VM OPNsense à partir du template OPNsenseTemplate

resource "proxmox_vm_qemu" "opnsenses" {

  for_each = var.opnsenses

  name        = each.value.name
  vmid        = each.value.vmid

  clone       = each.value.opnsense_template
  full_clone  = true
  onboot      = true
  agent       = 1
  agent_timeout = 300
  bios        = "seabios"
  scsihw      = "virtio-scsi-single"
  boot        = "order=scsi0;ide1"
  target_node = var.target_node


  memory      = 2048

  cpu {
    cores   = 2
    sockets = 1
  }

  # Disque principal SCSI (slot = scsi0)
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = "local-lvm"
    size    = "10G"
    cache   = "writeback"
  }

  serial {
      id   = 0
      type = "socket"
    }

}
