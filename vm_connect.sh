#!/bin/env bash
#Variables
VM="$1"
VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/vms"}
VM_USER="user"
#Functions
usage() {
  cat << EOF
USO: $0 VM

Este script conecta por ssh con la maquina virtual seleccionada.
EOF
}

connect_vm() {
    local VM_IP=$(./vm_get_ip.sh ${VM})
    ssh -i ${VM_BASE_DIR}/ssh/${VM} -l${VM_USER} ${VM_IP}
}
if [[ -z "$VM" ]]; then
  usage
  exit 1
fi
connect_vm