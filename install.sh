#!/bin/env bash
#Define variable names on env_scripts/common.sh
#VM_NETWORK=
#VM_BASE_DIR=
#Install dependencies - TODO
source env_scripts/common.sh

mkdir -p "${VM_BASE_DIR}"/{images,xml,init,base,ssh}
cp files/network.xml ${VM_BASE_DIR}/xml/network.xml
sed -i "s/YOURNETWORK/${VM_NETWORK}/g" ${VM_BASE_DIR}/xml/network.xml
virsh net-define ${VM_BASE_DIR}/xml/network.xml
virsh net-autostart ${VM_NETWORK}
virsh net-start ${VM_NETWORK}