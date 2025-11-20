lxc_linux = {
  "Adguard" = {
    lxc_id = 113
    name = "Adguard"
    cores = 1
    memory = 1024
    ipconfig0 = "172.16.0.3/24"
    gw = "172.16.0.254"
    disk_size = "10G"
    network_bridge = "vmbr0"
    }

    "UptimeKuma" = {
    lxc_id = 114
    name = "UptimeKuma"
    cores = 1
    memory = 1024
    ipconfig0 = "172.16.0.4/24"
    gw = "172.16.0.254"
    disk_size = "10G"
    network_bridge = "vmbr0"
    }

    "GLPI" = {
    lxc_id = 115
    name = "GLPI"
    cores = 2
    memory = 2048
    ipconfig0 = "172.16.0.5/24"
    gw = "172.16.0.254"
    disk_size = "30G"
    disk_size = "20G"
    network_bridge = "vmbr0"
    }
}

win_srv = {
  "WinSRV01" = {
    name = "WinSRV01"
    vmid = 201
    ipconfig0 = "ip=172.16.0.1/24,gw=172.16.0.254"
    dns = "8.8.8.8"

    }

  "WinSRV02" = {
    name = "WinSRV02"
    vmid = 202
    ipconfig0 = "ip=172.16.0.2/24,gw=172.16.0.254"
    dns = "172.16.0.1"

    }
}

opnsenses = {
  "OPNsense-Master" = {
    name = "OPNsense-Master"
    vmid = 301
    opnsense_template = "OpnSense-Master-Template"
    }

  "OPNsense-Backup" = {
    name = "OPNsense-Backup"
    vmid = 302
    opnsense_template = "OpnSense-Backup-Template"  
  }
}
