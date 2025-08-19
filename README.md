graph TD
subgraph Proxmox Host
eno1[eno1 (NIC física)]
vmbr0[vmbr0 (WAN)<br>136.243.134.95/32]
vmbr1[vmbr1 (LAN)<br>172.16.0.200/20]

        eno1 --> vmbr0
    end

    Internet[Internet<br>via GW 136.243.134.65]
    vmbr0 --> Internet

    subgraph VM: OPNsense
        opnsense[OPNsense<br>136.243.134.89/32]
    end

    vmbr0 --> opnsense

    note right of vmbr1
        vmbr1 sin bridge-ports físicos
        solo tráfico interno (LAN virtual)
    end
