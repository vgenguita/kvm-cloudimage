#!/bin/env bash

# Variables
VM_USER="user"
VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/vms"}
VM_IMAGE_PATH="${VM_BASE_DIR}/images/$1.img"
CI_IMAGE_PATH="${VM_BASE_DIR}/images/$1-cidata.iso"

# Functions
## List Installed VMS
vm_list()
{
    virsh list
}

vm_net_get_mac()
{
    local VM=$1
    MAC_VM=$(virsh domiflist "$VM" | awk '{ print $5 }' | tail -2 | head -1)
    echo $MAC_VM
}
## Get VM ip (only on NAT)
vm_net_get_ip()
{
    local VM="$1"
    # Obtener la dirección MAC de la interfaz de red
    MAC_VM=$(vm_net_get_mac $VM)
    if [[ -z "$MAC_VM" ]]; then
        echo "Error: No se pudo encontrar la dirección MAC para '$VM'"
        return 1
    fi
    # Obtener la dirección IP a partir de la dirección MAC
    VM_IP_ADDRESS=$(arp -a | grep "$MAC_VM" | awk '{ print $2 }' | sed 's/[()]//g')
    if [[ -z "$VM_IP_ADDRESS" ]]; then
        echo "Error: No se pudo encontrar la dirección IP para la dirección MAC '$MAC_VM'"
        return 1
    fi
    echo "$VM_IP_ADDRESS"
}

vm_net_create_netplan()
{
    local VM=$1
    local MAV_VM=$2
cat <<EOF > "$VM_BASE_DIR/init/${VM}-netplan"
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        enp1s0:
            addresses:
              - ${IP}/24
            nameservers:
              addresses:
                - 208.67.222.222
                - 208.67.220.220
            match:
                macaddress: ${MAC_VM}
            set-name: enp1s0
    version: 2
EOF
}

vm_net_bridge_set_ip()
{
    local VM="$1"
    local IP="$2"
    MAC_VM=$(vm_net_get_mac "$VM")
    CURRENT_IP=$(vm_net_get_ip "$VM")
    define_netplan
    # Obtener la dirección IP de la máquina virtual
    scp -i ${VM_BASE_DIR}/ssh/${VM} \
        -r $VM_BASE_DIR/init/${VM}-netplan \
        ${VM_USER}@${CURRENT_IP}:50-cloud-init.yaml
    ssh -i ${VM_BASE_DIR}/ssh/${VM} -l${VM_USER} ${CURRENT_IP} "bash -s" -- < ../vm_example_scripts/apply_netplan.sh
}
## Connect to an existent VM using ssh
vm_connect()
{
    local VM=$1
    local VM_IP=$(get_vm_ip_address "$VM")
    ssh -i ${VM_BASE_DIR}/ssh/${VM} -l${VM_USER} ${VM_IP}
}

## Delete VM
vm_delete ()
{
    local VM=$1
    if [[ -f "$VM_IMAGE_PATH" ]]; then
    # Safely remove the VM with confirmation
    read -p "Are you sure you want to remove the VM '$VM' (y/N)? " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Attempt to stop the VM before deleting
        virsh destroy "$VM" 2>/dev/null || true
        # Delete VM definition and associated images
        virsh undefine "$VM" 2>/dev/null || true
        rm -fv "$VM_IMAGE_PATH" "$CI_IMAGE_PATH"
        rm ${VM_BASE_DIR}/xml/$1.xml
        rm ${VM_BASE_DIR}/ssh/$1*
        rm ${VM_BASE_DIR}/init/$1-user-data
        rm ${VM_BASE_DIR}/init/$1-meta-data
    else
        echo "VM removal cancelled."
    fi
    else
    # Handle case where VM image is not found
    echo "Cannot find VM image file '$VM_IMAGE_PATH'. No action taken."
    fi
}