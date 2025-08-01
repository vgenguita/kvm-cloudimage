#!/bin/env bash
#Define variable names on env_scripts/common.sh
#VM_NETWORK=
#VM_BASE_DIR=
#Install dependencies
source env_scripts/common.sh
source env_scripts/functions.sh
detect_distro

case $DISTRO in
    ubuntu|debian)
        install_debian_ubuntu
        ;;
    arch)
        install_arch
        ;;
    fedora)
        install_fedora
        ;;
    *)
        print_error "Distribution not supported: $DISTRO"
        print_info "Supported: Ubuntu, Debian, Arch, Fedora"
        exit 1
            ;;
    esac
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG kvm $(whoami)
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

mkdir -p "${VM_BASE_DIR}"/{images,xml,init,base,ssh}
cp files/network.xml ${VM_BASE_DIR}/xml/network.xml
sed -i "s/YOURNETWORK/${VM_NETWORK}/g" ${VM_BASE_DIR}/xml/network.xml
virsh net-define ${VM_BASE_DIR}/xml/network.xml
virsh net-autostart ${VM_NETWORK}
virsh net-start ${VM_NETWORK}
newgrp libvirt
