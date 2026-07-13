#!/bin/env bash
#Define variable names on env_scripts/common.sh
#VM_NETWORK=
#VM_BASE_DIR=
#Install dependencies
# Check if the setup file exists and already contains INSTALLED = "Y"
source env_scripts/common.sh
source env_scripts/functions.sh
if [ -f "${VM_CONFIG_DIR}/setup" ] && grep -Fxq 'INSTALLED="Y"' "${VM_CONFIG_DIR}/setup"; then
    echo "Setup already completed. Skipping execution."
    exit 1
fi
detect_distro
case $DISTRO in
    ubuntu|debian)
        install_debian_ubuntu
        ;;
    arch | archcraft)
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

## Permissions and groups
LIBVIRT_GROUP=$(grep qemu /etc/group | awk -F ':' '{print $1}' | grep -v kvm)

sudo chmod 750 "${HOME}"
sudo usermod -aG libvirt "${USER}"
sudo usermod -aG kvm "${USER}"
sudo usermod -aG "${LIBVIRT_GROUP}" "${USER}"
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

## Folder structure
mkdir -p "${VM_BASE_DIR}"/{images,xml,init,base,ssh}
mkdir -p "${VM_CONFIG_DIR}"
touch "${VM_CONFIG_DIR}/setup"
echo 'INSTALLED="Y"' >> "${VM_CONFIG_DIR}/setup"
echo "LIBVIRT_GROUP=\"${LIBVIRT_GROUP}\""  >> "${VM_CONFIG_DIR}/setup"
#Isolated network
cp files/network-host-only.xml ${VM_BASE_DIR}/xml/network-host-only.xml
sed -i "s/YOURNETWORK/${VM_NETWORK_HOSTONLY}/g" ${VM_BASE_DIR}/xml/network-host-only.xml
virsh --connect qemu:///system net-define ${VM_BASE_DIR}/xml/network-host-only.xml
virsh --connect qemu:///system net-autostart ${VM_NETWORK_HOSTONLY}
virsh --connect qemu:///system net-start ${VM_NETWORK_HOSTONLY}
#NAT
cp files/network-nat.xml ${VM_BASE_DIR}/xml/network-nat.xml
sed -i "s/YOURNETWORK/${VM_NETWORK_NAT}/g" ${VM_BASE_DIR}/xml/network-nat.xml
virsh --connect qemu:///system net-define ${VM_BASE_DIR}/xml/network-nat.xml
virsh --connect qemu:///system net-autostart ${VM_NETWORK_NAT}
virsh --connect qemu:///system net-start ${VM_NETWORK_NAT}
echo "Setup completed. Logout and login your session again now."
