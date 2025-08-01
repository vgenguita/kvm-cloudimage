#!/usr/bin/env -S bash

# Functions
pause()
{
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

# Printe messages
print_info() {
    echo -e "\e[1;34m[INFO]\e[0m $1"
}

print_success() {
    echo -e "\e[1;32m[OK]\e[0m $1"
}

print_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $1"
}

# Detectar distribución
detect_distro() 
{
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    # elif [ -f /etc/centos-release ] || [ -f /etc/fedora-release ]; then
    #     if grep -q "Fedora" /etc/fedora-release; then
    #         DISTRO="fedora"
    #     else
    #         DISTRO="centos"
    #     fi
    else
        print_error "No se pudo detectar la distribución."
        exit 1
    fi
}


install_debian_ubuntu() {
    print_info "Updating packages..."
    sudo apt update || { print_error "Error updating packages."; exit 1; }

    print_info "Installing libvirt"
    sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils|| {
        print_error "Error installing packages."
        exit 1
    }

    # Habilitar e iniciar el servicio
    sudo systemctl enable libvirtd || sudo systemctl enable libvirt-bin
    sudo systemctl start libvirtd || sudo systemctl start libvirt-bin
}

install_arch() {
    print_info "Updating packages..."
    sudo pacman -Syu --noconfirm || { print_error "Error updating packages."; exit 1; }

    print_info "Installing libvirt."
    sudo pacman -S --noconfirm qemu libvirt virt-manager dnsmasq iptables bridge-utils|| {
        print_error "Error installing packages."
        exit 1
    }
}

install_fedora() {
    print_info "Updating packages..."
    sudo dnf upgrade -y|| { print_error "Error updating packages."; exit 1; }

    print_info "Installing libvirt."
    sudo sudo dnf install -y @virtualization qemu libvirt bridge-utils|| {
        print_error "Error installing packages."
        exit 1
    }
}


check_host_os()
{
    local HOST_OS=$(cat /etc/os-release | grep -v VERSION_ID |grep "ID=" | awk -F'=' '{print $2}')
    if [ $HOST_OS == "debian" ]; then
    source env_scripts/older_os.sh
    else 
    source env_scripts/newer_os.sh
    fi
}


generate_openbsd_image()
{
    local CURRENT_PATH="$PWD"
    VM_BASE_IMAGE_NAME=${VM_BASE_IMAGE%%.*}
    VM_BASE_IMAGE_EXTENSION=${VM_BASE_IMAGE#*.}
    git clone https://github.com/hcartiaux/openbsd-cloud-image.git
    cd openbsd-cloud-image
    ./build_openbsd_qcow2.sh \
        --image-file ${VM_BASE_IMAGE_NAME}.${VM_BASE_IMAGE_EXTENSION} \
        --disklabel custom/disklabel.cloud \
        --size ${VM_DISK_SIZE} \
        -b
    if ! test -f "${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION}"; then
        mv images/${VM_BASE_IMAGE_NAME}.${VM_BASE_IMAGE_EXTENSION} ${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION}
        sudo chown -R $USER:libvirt-qemu "${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION}"
        cd ${CURRENT_PATH}
        rm -r openbsd-cloud-image
    else
        echo "${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION} already exists. Delete VM with "delete" option"
         cd ${CURRENT_PATH}
        rm -r openbsd-cloud-image
        exit 1
    fi
}

show_vm_menu() {
    # Display dynamic OS selection menu
    echo "Select VM OS:"
    echo "--------------"

    # Array to store valid IDs for validation
    VALID_IDS=()
    while IFS= read -r entry; do
        DECODED=$(echo "$entry" | base64 --decode)
        ID=$(echo "$DECODED" | jq -r '.id')
        NAME=$(echo "$DECODED" | jq -r '.name')
        printf "%2s. %s\n" "$ID" "$NAME"
        VALID_IDS+=("$ID")
    done < <(jq -r '.os_variants[] | @base64' "$OS_JSON_FILE")

    # Calculate max ID for range validation
    ID_MAX=$(jq -r '[.os_variants[].id] | max' "$OS_JSON_FILE")
    ID_MIN=$(jq -r '[.os_variants[].id] | min' "$OS_JSON_FILE")

    # Read user input
    read -r -p "Enter your choice [${ID_MIN}-${ID_MAX}]: " CHOICE

    # Validate input: must be a number and within range
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
        echo "Error: Please enter a valid number." >&2
        exit 1
    fi

    if (( CHOICE < ID_MIN || CHOICE > ID_MAX )); then
        echo "Error: Please enter a number between ${ID_MIN} and ${ID_MAX}." >&2
        exit 1
    fi

    # Get selected OS variant
    SELECTED=$(jq -r ".os_variants[] | select(.id == ${CHOICE})" "$OS_JSON_FILE")

    if [ -z "$SELECTED" ]; then
        echo "Error: Invalid selection." >&2
        exit 1
    fi

    # Export variables in uppercase
    VM_OS_VARIANT=$(echo "$SELECTED" | jq -r '.variant')
    VM_OS_TYPE=$(echo "$SELECTED" | jq -r '.os_type')
    VM_BASE_IMAGE_URL=$(echo "$SELECTED" | jq -r '.url')
    VM_BASE_IMAGE=$(echo "$SELECTED" | jq -r '.origin_image_name')
    VM_BOOT_TYPE=$(echo "$SELECTED" | jq -r '.boot_type')
    VM_CHECKSUMS_URL=$(echo "$SELECTED" | jq -r '.md5sum')

    # Optional: Debug
    # echo "Selected OS variant: ${VM_OS_VARIANT}"
}
compare_checksum()
{
    CHECKSUM_TMP_FOLDER=$(mktemp)

    wget --recursive \
    --user-agent="Mozilla/5.0 (X11; Linux x86_64)" \
    -O "${CHECKSUM_TMP_FOLDER}" \
    "${VM_CHECKSUMS_URL}"

    if [[ "$VM_OS_TYPE" == "BSD" &&  "${VM_OS_VARIANT}" == *"freebsd"* ]]; then
        if [[ "${VM_BASE_IMAGE}" == *"zfs"* ]]; then
            VM_BASE_IMAGE_CHECKSUM=$(grep "FreeBSD-14.3-STABLE-amd64-BASIC-CLOUDINIT" "${CHECKSUM_TMP_FOLDER}" | grep "zfs.qcow2.xz" | awk '{print $4}') 
        else
            VM_BASE_IMAGE_CHECKSUM=$(grep "FreeBSD-14.3-STABLE-amd64-BASIC-CLOUDINIT" "${CHECKSUM_TMP_FOLDER}" | grep "ufs.qcow2.xz" | awk '{print $4}') 
        fi
    else
        VM_BASE_IMAGE_CHECKSUM=$(grep "$VM_BASE_IMAGE_NAME.${VM_BASE_IMAGE_EXTENSION}" "${CHECKSUM_TMP_FOLDER}" | awk '{print $1}')
    fi
    if [[ "${VM_CHECKSUMS_URL}" == *"SHA256"* || "${VM_CHECKSUMS_URL}" == *"sha256"* ]]; then
	HASH_CMD="sha256sum"
    elif [[ "${VM_CHECKSUMS_URL}" == *"SHA512"* ]]; then
	HASH_CMD="sha512sum"
    else
	echo "ERROR: Unknown checksum type in URL: $CHECKSUM_URL"
	exit 1
    fi
    BASE_FILE_CHECKSUM=$(${HASH_CMD} ${VM_BASE_IMAGE_LOCATION} | awk '{print $1}')
	if [ "${BASE_FILE_CHECKSUM}" = "${VM_BASE_IMAGE_CHECKSUM}" ]; then
       		echo "Checksum OK: ${BASE_FILE_CHECKSUM}"
    	else
        	echo "ERROR: MD5 checksum does NOT match!"
        	echo "Expected: ${VM_BASE_IMAGE_CHECKSUM}"
        	echo "Got:      ${BASE_FILE_CHECKSUM}"
        	exit 1
    fi
}
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
        echo "Error: The MAC address could not be found for '$VM'"
        return 1
    fi
    # Obtener la dirección IP a partir de la dirección MAC
    VM_IP_ADDRESS=$(arp -a | grep "$MAC_VM" | awk '{ print $2 }' | sed 's/[()]//g')
    if [[ -z "$VM_IP_ADDRESS" ]]; then
        echo "Error: Could not find IP address for MAC address '$MAC_VM'"
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
        ${VM_USERNAME}@${CURRENT_IP}:50-cloud-init.yaml
    ssh -i ${VM_BASE_DIR}/ssh/${VM} -l${VM_USERNAME} ${CURRENT_IP} "bash -s" -- < ../vm_example_scripts/apply_netplan.sh
}

vm_net_set_bridge_mode()
{
    if [[ -n $VM_BRIDGE_INT ]]; then
            LIBVIRT_NET_OPTION="model=virtio,bridge=${VM_BRIDGE_INT}"
    fi
}
## Connect to an existent VM using ssh
vm_connect()
{
    local VM=$1
    local VM_IP=$(vm_net_get_ip "$VM")
    ssh -i ${VM_BASE_DIR}/ssh/${VM} -l${VM_USERNAME} ${VM_IP}
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
        rm ${VM_BASE_DIR}/ssh/$1
        rm ${VM_BASE_DIR}/ssh/$1.pub
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
vm_download_base_image()
{
    if [[ "$VM_OS_TYPE" == "BSD" &&  "${VM_OS_VARIANT}" == *"freebsd"* ]]; then
        if [[ "${VM_BASE_IMAGE}" == *"zfs"* ]]; then
            VM_BASE_IMAGE_NAME="${VM_OS_VARIANT}-zfs"
        else
            VM_BASE_IMAGE_NAME="${VM_OS_VARIANT}-ufs"
        fi
        VM_BASE_IMAGE_EXTENSION="qcow2.xz"
    else
        VM_BASE_IMAGE_NAME=${VM_BASE_IMAGE%%.*}
        VM_BASE_IMAGE_EXTENSION=${VM_BASE_IMAGE#*.}
    fi
    VM_BASE_IMAGE_LOCATION="${VM_BASE_DIR}/${VM_BASE_IMAGES}/${VM_BASE_IMAGE_NAME}.${VM_BASE_IMAGE_EXTENSION}"
    if ! test -f "${VM_BASE_IMAGE_LOCATION}"; then
       wget --recursive \
        --user-agent="Mozilla/5.0 (X11; Linux x86_64)" \
        -O "${VM_BASE_IMAGE_LOCATION}" \
        ${VM_BASE_IMAGE_URL}
    fi
}


vm_create_guest_image()
{
    if [[  "$VM_OS_TYPE" == "BSD" &&  "${VM_OS_VARIANT}" == *"freebsd"* ]]; then
        if ! test -f "${VM_BASE_DIR}/images/${VM_HOSTNAME}.qcow"; then
            xz -d ${VM_BASE_IMAGE_LOCATION}
        fi
        VM_BASE_IMAGE_EXTENSION="qcow2"
        VM_BASE_IMAGE_LOCATION="${VM_BASE_DIR}/${VM_BASE_IMAGES}/${VM_BASE_IMAGE_NAME}.${VM_BASE_IMAGE_EXTENSION}"
    fi
    if ! test -f "${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION}"; then
        qemu-img convert \
            -O qcow2  \
            "${VM_BASE_IMAGE_LOCATION}" \
            "${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION}"
        qemu-img resize \
            "${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION}" \
            "${VM_DISK_SIZE}G"
        sudo chown -R $USER:libvirt-qemu "${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION}"
    else
        echo "${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION} already exists. Delete VM with "delete" option"
        exit 1
    fi
}

vm_generate_ssh_hey()
{
  ssh-keygen -t rsa -b 4096 -N '' -f "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}"
  chmod 600 ${VM_BASE_DIR}/ssh/${VM_HOSTNAME}.pub
  SSH_PUB_KEY=$(cat "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}.pub")
  #ssh-keygen -y -f "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}" > "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}".pub.txt
  #SSH_PUB_KEY=$(cat "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}".pub.txt)
  #rm "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}".pub.txt
}

# vm_gen_user_data()
# {
# VM_USER_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
# VM_USER_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_USER_PASS})
# #FREEBSD GUEST
# if [[ "$VM_OS_TYPE" == "BSD" &&  "${VM_OS_VARIANT}" == *"freebsd"*  ]]; then
# VM_ROOT_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
# VM_ROOT_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_ROOT_PASS})
# cat <<EOF > "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
# #cloud-config
# hostname: ${VM_HOSTNAME}
# package_reboot_if_required: true
# package_update: true
# package_upgrade: true
# packages:
# - sudo
# - vim
# ssh_pwauth: false
# users:
#   - name: root
#     lock_passwd: false
#     hashed_passwd: ${VM_ROOT_PASS_HASH}
#   - name: ${VM_USERNAME}
#     ssh_authorized_keys:
#       - ${SSH_PUB_KEY}
#     lock_passwd: true
#     groups: wheel
#     shell: /bin/tcsh

# write_files:
#   - path: /usr/local/etc/sudoers
#     content: |
#       %wheel ALL=(ALL) NOPASSWD: ALL
#     append: true
# EOF
# #OPENBSD
# elif [[ "$VM_OS_TYPE" == "BSD" &&  "${VM_OS_VARIANT}" == *"openbsd"*  ]]; then
# #"disable_root": true
# cat <<EOF > "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
# #cloud-config
# "hostname": ${VM_HOSTNAME}
# "package_upgrade": true
# "packages":
# - "bash"
# - "vim--no_x11"
# "ssh_pwauth": false
# "users":
# - "name": ${VM_USERNAME}
#   "sudo": "ALL=(ALL) NOPASSWD:ALL"
#   "groups": wheel
#   "hashed_passwd": "!"
#   "lock_passwd": true
#   "shell": "/usr/local/bin/bash"
#   "ssh_authorized_keys":
#   - ${SSH_PUB_KEY}
# - "name": "root"
#   "hashed_passwd": "!"
#   "lock_passwd": true
# write_files:
#   - path: /etc/sudoers
#     content: |
#       %wheel ALL=(ALL) NOPASSWD: ALL
#     append: true
# EOF
# else
# cat <<EOF > "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
# #cloud-config
# hostname: ${VM_HOSTNAME}
# # manage_etc_hosts: false
# ssh_pwauth: true
# disable_root: true
# users:
# - name: ${VM_USERNAME}
#   hashed_passwd: ${VM_USER_PASS_HASH}
#   sudo: ALL=(ALL) NOPASSWD:ALL
#   shell: /bin/bash
#   lock-passwd: false
#   ssh_authorized_keys:
#     - ${SSH_PUB_KEY}
# EOF
# fi
# }


vm_gen_user_data()
{
    if [[ "$VM_OS_TYPE" == "BSD" &&  "${VM_OS_VARIANT}" == *"freebsd"*  ]]; then
        VM_USER_DATA_FILE="files/freebsd-user-data"
    elif [[ "$VM_OS_TYPE" == "BSD" &&  "${VM_OS_VARIANT}" == *"openbsd"*  ]]; then
        VM_USER_DATA_FILE="files/openbsd-user-data"
    else
        VM_USER_DATA_FILE="files/linux-user-data"
    fi
    cp ${VM_USER_DATA_FILE} "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
    sed -i "s|__SSH_PUB_KEY__|${SSH_PUB_KEY}|g" "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
    sed -i "s|__VM_USERNAME__|${VM_USERNAME}|g" "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
}

vm_gen_meta_data()
{
    cp files/meta-data "$VM_BASE_DIR/init/${VM_HOSTNAME}-meta-data"
    sed -i "s|__VMname__|${VM_HOSTNAME}|g" "$VM_BASE_DIR/init/${VM_HOSTNAME}-meta-data"
}

vm_set_guest_type()
{
    if [[ "$VM_OS_TYPE" == "BSD" ]]; then
        if [[ "${VM_OS_VARIANT}" == *"freebsd"* ]]; then
            VM_OS_VARIANT=${GUEST_OS_TYPE_FREEBSD}
        fi
        if [[ "${VM_OS_VARIANT}" == *"openbsd"* ]]; then
            VM_OS_VARIANT=${GUEST_OS_TYPE_OPENBSD}
        fi
    elif  [[ "${VM_OS_VARIANT}" == *"debian13"* ]]; then
        VM_OS_VARIANT=${GUEST_OS_TYPE_DEBIAN}
    fi
}

vm_guest_install()
{
    VM_INSTALL_OPTS=""
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --name ${VM_HOSTNAME}" 
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --memory ${VM_MEM_SIZE}" 
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --vcpus ${VM_VCPUS}" 
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --os-variant=${VM_OS_VARIANT}" 
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --disk ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img,device=disk,bus=virtio" 
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --network ${LIBVIRT_NET_OPTION}"
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --autostart" 
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --import --noautoconsole" 
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --cloud-init user-data=${VM_BASE_DIR}/init/${VM_HOSTNAME}-user-data,meta-data=$VM_BASE_DIR/init/${VM_HOSTNAME}-meta-data" 
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --channel unix,mode=bind,target_type=virtio,name=org.qemu.guest_agent.0"
    if [ "$VM_BOOT_TYPE" = "UEFI" ]; then
        VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --boot uefi"
    fi
    eval virt-install $VM_INSTALL_OPTS

    virsh dumpxml "${VM_HOSTNAME}" > "${VM_BASE_DIR}/xml/${VM_HOSTNAME}.xml"
    clear
    echo  "VM ${VM_HOSTNAME} Created!"
    echo  "NOTE: It may take some time for the virtual machine to be available if it is a BSD flavor. You can check the status of the virtual machine with the following command:"
    echo "root pass is(only for BSD flavour): ${VM_USER_PASS}"
    echo "user pass is: ${VM_USER_PASS}"
    echo  "virsh console ${VM_HOSTNAME} --safe"
}
