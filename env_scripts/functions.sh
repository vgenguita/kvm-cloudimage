#!/bin/env bash

# Functions

check_host_os()
{
    local HOST_OS=$(cat /etc/os-release | grep -v VERSION_ID |grep "ID=" | awk -F'=' '{print $2}')
    if [ $HOST_OS == "debian" ]; then
    source env_scripts/older_os.sh
    else 
    source env_scripts/newer_os.sh
    fi
}


show_vm_menu()
{
    # Show dinamic menu
    echo "Select VM OS:"
    for entry in $(jq -r '.os_variants[] | @base64' "$OS_JSON_FILE"); do
        decoded=$(echo "$entry" | base64 --decode)
        id=$(echo "$decoded" | jq -r .id)
        name=$(echo "$decoded" | jq -r .name)
        echo "$id. $name"
    done

    # ID_MAX calculation
    ID_MAX=$(jq -r '[.os_variants[].id] | max' "$OS_JSON_FILE")

    # Read input
    read -r -p "Enter your choice [1-${ID_MAX}]: " answer
    if ! [[ "$answer" =~ ^[0-9]+$ ]] || (( answer < 1 || answer > ID_MAX )); then
        echo "Invalid option. Please enter a number between 1 and ${ID_MAX}."
        exit 1
    fi

    selected=$(jq -r ".os_variants[] | select(.id == $answer)" "$OS_JSON_FILE")

    if [ -z "$selected" ]; then
        echo "Invalid option."
        exit 1
    fi

    # Asignar variables
    VM_OS_VARIANT=$(echo "$selected" | jq -r .variant)
    VM_OS_TYPE=$(echo "$selected" | jq -r .os_type)
    VM_BASE_IMAGE_URL=$(echo "$selected" | jq -r .url)
    VM_BASE_IMAGE=$(echo "$selected" | jq -r .origin_image_name)
    VM_BOOT_TYPE=$(echo "$selected" | jq -r .boot_type)
    VM_CHECKSUMS_URL=$(echo "$selected" | jq -r .md5sum)
}

compare_checksum()
{
    CHECKSUM_TMP_FOLDER=$(mktemp)
    curl -s -o "${CHECKSUM_TMP_FOLDER}" "${VM_CHECKSUMS_URL}"
    if [[ "$VM_OS_TYPE" == "freebsd" ]]; then
        if [[ "${VM_BASE_IMAGE}" == *"zfs"* ]]; then
            VM_BASE_IMAGE_CHECKSUM=$(grep "FreeBSD-14.3-STABLE-amd64-BASIC-CLOUDINIT" "${CHECKSUM_TMP_FOLDER}" | grep "zfs.qcow2.xz" | awk '{print $4}') 
        else
            VM_BASE_IMAGE_CHECKSUM=$(grep "FreeBSD-14.3-STABLE-amd64-BASIC-CLOUDINIT" "${CHECKSUM_TMP_FOLDER}" | grep "ufs.qcow2.xz" | awk '{print $4}') 
        fi
    else
        VM_BASE_IMAGE_CHECKSUM=$(grep "$VM_BASE_IMAGE_NAME.${VM_BASE_IMAGE_EXTENSION}" "${CHECKSUM_TMP_FOLDER}" | awk '{print $1}')
    fi
    if [[ "${VM_CHECKSUMS_URL}" == *"SHA256"* ]]; then
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
    echo "VM: $VM"
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
    if [[ "$VM_OS_TYPE" == "freebsd" ]]; then
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
        wget -O "${VM_BASE_IMAGE_LOCATION}" ${VM_BASE_IMAGE_URL}
    fi
}


vm_create_guest_image()
{
    echo "Creating a qcow2 image file ${VM_BASE_DIR}/images/${VM_HOSTNAME}.${VM_DISK_EXTENSION} that uses the cloud image file ${VM_BASE_IMAGE_LOCATION} as its base"
    if [[ "$VM_OS_TYPE" == "freebsd" ]]; then
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

vm_gen_user_data()
{
VM_USER_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
VM_USER_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_USER_PASS})
#FREEBSD GUEST
if [[ "$VM_OS_TYPE" == "freebsd" ]]; then
VM_ROOT_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
VM_ROOT_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_ROOT_PASS})
cat <<EOF > "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
#cloud-config
hostname: ${VM_HOSTNAME}
package_reboot_if_required: true
package_update: true
package_upgrade: true
packages:
- sudo
- vim
ssh_pwauth: false
users:
  - name: root
    lock_passwd: false
    hashed_passwd: ${VM_ROOT_PASS_HASH}
  - name: ${VM_USERNAME}
    ssh_authorized_keys:
      - ${SSH_PUB_KEY}
    lock_passwd: true
    groups: wheel
    shell: /bin/tcsh
write_files:
  - path: /usr/local/etc/sudoers
    content: |
      %wheel ALL=(ALL) NOPASSWD: ALL
    append: true
EOF
#LINUX GUEST
else
cat <<EOF > "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
#cloud-config
hostname: ${VM_HOSTNAME}
# manage_etc_hosts: false
ssh_pwauth: true
disable_root: true
users:
- name: ${VM_USERNAME}
  hashed_passwd: ${VM_USER_PASS_HASH}
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  lock-passwd: false
  ssh_authorized_keys:
    - ${SSH_PUB_KEY}
EOF
fi
}


# vm_gen_user_data()
# {   
#     VM_USER_DATA_FILE=files/user-data
#     VM_USER_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
#     VM_USER_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_USER_PASS})
#     #FREEBSD GUEST
#     if [[ "$VM_OS_TYPE" == "freebsd" ]]; then
#         VM_ROOT_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
#         VM_ROOT_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_ROOT_PASS})
#         VM_USER_DATA_FILE="files/freebsd-user-data"
#     fi
#     cp ${VM_USER_DATA_FILE} "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
#     sed -i "s|__SSH_KEY__|${SSH_PUB_KEY}|g" "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
#     sed -i "s| __USER_PASSWORD__|${VM_USER_PASS_HASH}|g" "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
#     sed -i "s| __USER_NAME__|${VM_USERNAME}|g" "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
#     if [[ "$VM_OS_TYPE" == "freebsd" ]]; then
#         sed -i "s| __ROOT_PASSWORD__|${VM_ROOT_PASS_HASH} |g" "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
#     fi
# }

vm_gen_meta_data()
{
    cp files/meta-data "$VM_BASE_DIR/init/${VM_HOSTNAME}-meta-data"
    sed -i "s|__VMname__|${VM_HOSTNAME}|g" "$VM_BASE_DIR/init/${VM_HOSTNAME}-meta-data"
}

vm_set_guest_type()
{
    if [[ "$VM_OS_TYPE" == "freebsd" ]]; then
        VM_OS_VARIANT=${GUEST_OS_TYPE_FREEBSD}
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
    if [ "$VM_BOOT_TYPE" = "UEFI" ]; then
        VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --boot uefi"
    fi
    eval virt-install $VM_INSTALL_OPTS

    virsh dumpxml "${VM_HOSTNAME}" > "${VM_BASE_DIR}/xml/${VM_HOSTNAME}.xml"
    echo "Root password: $VM_ROOT_PASS"
    echo "User password: $VM_USER_PASS"
}
