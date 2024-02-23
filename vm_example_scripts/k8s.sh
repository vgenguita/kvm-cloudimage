#!/bin/bash
VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/vms"}
VM_USER="user"
VM=$1
VM_IP=$(sh ../base_scripts/vm_get_ip.sh ${VM})
scp -i ${VM_BASE_DIR}/ssh/${VM} \
    -r k8s \
    ${VM_USER}@${VM_IP}:k8s
clear
echo "############################"
echo "Connecting to VM, execute:"
echo "cd k8s"
echo "01_install_packages.sh"
echo "02_basic_deploys.sh"
echo "###########################"
cd ../base_scripts
sh vm_connect.sh ${VM}