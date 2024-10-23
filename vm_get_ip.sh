#!/bin/env bash
usage() {
  cat << EOF
USO: $0 VM

Este script recupera la dirección IP de una máquina virtual administrada por virsh.

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

# Obtener el nombre del host de la máquina virtual
VM="$1"

if [[ -z "$VM" ]]; then
  usage
  exit 1
fi

# Obtener la dirección IP de la máquina virtual
get_vm_ip_address "$VM"
