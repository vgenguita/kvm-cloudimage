#!/bin/bash
VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/vms"}
VM_USER="user"
MAC_VM=
usage() {
  cat << EOF
USO: $0 VM

Este script setea la dirección IP de una máquina virtual administrada por virsh.

EOF
}

# Función para obtener la dirección IP de la máquina virtual
get_vm_ip_address() {
  local VM="$1"

  # Obtener la dirección MAC de la interfaz de red
  MAC_VM=$(virsh domiflist "$VM" | awk '{ print $5 }' | tail -2 | head -1)
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


define_netplan()
{
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
# Obtener el nombre del host de la máquina virtual
VM="$1"
IP="$2"
if [[ -z "$VM" ]]; then
  usage
  exit 1
fi

if [[ -z "$IP" ]]; then
  usage
  exit 1
fi
MAC_VM=$(virsh domiflist "$VM" | awk '{ print $5 }' | tail -2 | head -1)
CURRENT_IP=$(get_vm_ip_address "$VM")
define_netplan
# Obtener la dirección IP de la máquina virtual
scp -i ${VM_BASE_DIR}/ssh/${VM} \
    -r $VM_BASE_DIR/init/${VM}-netplan \
    ${VM_USER}@${CURRENT_IP}:50-cloud-init.yaml
ssh -i ${VM_BASE_DIR}/ssh/${VM} -l${VM_USER} ${CURRENT_IP} "bash -s" -- < ../vm_example_scripts/apply_netplan.sh

