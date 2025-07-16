#!/bin/env bash
source common.sh
VM_HOSTNAME=
VM_DISK_SIZE=20
VM_DISK_FORMAT=qcow2
VM_MEM_SIZE=2048
VM_VCPUS=2
VM_BASE_IMAGE=
VM_OS_VARIANT=
VM_BRIDGE_INT=
VM_BASE_IMAGE_LOCATION=
VM_NET_USED="default"
#LIBVIRT_NET_OPTION="network=$VM_NET_USED,model=e1000"
LIBVIRT_NET_MODEL="virtio"
LIBVIRT_NET_OPTION="network=$VM_NET_USED,model=$LIBVIRT_NET_MODEL"

#LIBVIRT_NET_OPTION="model=e1000"

# Functions
usage()
{
cat << EOF
usage: $0 options

Quickly create guest VMs using cloud image files and cloud-init.

OPTIONS:
   -h      Show this message
   -n      Host name (required)
   -b      bridge interface name (bridge network is used)
   -r      RAM in MB (defaults to ${VM_MEM_SIZE})
   -c      Number of VCPUs (defaults to ${VM_VCPUS})
   -s      Amount of storage to allocate in GB (defaults to ${VM_DISK_SIZE})
   -v      Verbose
EOF
}

HOST_OS=$(cat /etc/os-release | grep -v VERSION_ID |grep "ID=" | awk -F'=' '{print $2}')
if [ $HOST_OS == "debian" ]; then
  source env_scripts/older_os.sh
else 
  source env_scripts/newer_os.sh
fi

#create_network()
#{
#virsh net-define mynet.xml
#virsh net-autostart mynet
#virsh net-start mynet
#}
download_base_image()
{
VM_BASE_IMAGE_NAME=$(basename "${VM_BASE_IMAGE_NAME}" .img)
VM_BASE_IMAGE_LOCATION="${VM_BASE_DIR}/${VM_BASE_IMAGES}/$VM_BASE_IMAGE_NAME.${VM_DISK_FORMAT}"
if ! test -f "${VM_BASE_IMAGE_LOCATION}"; then
  wget -O "${VM_BASE_IMAGE_LOCATION}" ${VM_BASE_IMAGE}
fi
}

gen_linux_user_data()
{
VM_USER_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
VM_USER_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_USER_PASS})
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
}

check_hash()
{	
	if [[ "${VM_CHECKSUMS_URL}" == *"SHA256SUMS"* ]]; then
		HASH_CMD="sha256sum"
	elif [[ "${VM_CHECKSUMS_URL}" == *"SHA512SUMS"* ]]; then
		HASH_CMD="sha512sum"
	else
		echo "ERROR: Unknown checksum type in URL: $CHECKSUM_URL"
		exit 1
	fi
	BASE_FILE_CHECKSUM=$(${HASH_CMD} -b ${VM_BASE_IMAGE_LOCATION} | awk '{print $1}')
	if [ "${BASE_FILE_CHECKSUM}" = "${VM_BASE_IMAGE_CHECKSUM}" ]; then
        echo "Checksum OK: ${BASE_FILE_CHECKSUM}"
    else
        echo "ERROR: MD5 checksum does NOT match!"
        echo "Expected: ${VM_BASE_IMAGE_CHECKSUM}"
        echo "Got:      ${BASE_FILE_CHECKSUM}"
        exit 1
    fi
}


gen_freebsd_user_data()
{
#VM_ROOT_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16; echo)
VM_ROOT_PASS="changeme"
echo "Generated root passwd: ${VM_ROOT_PASS}"
VM_ROOT_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_ROOT_PASS})
# Write FreeBSD 13.2 user-data
VM_USER_PASS="sasasa123"
VM_USER_PASS_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 ${VM_USER_PASS})
cat <<EOF > "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data"
#cloud-config
users:
  - name: root
    lock_passwd: false
    hashed_passwd: ${VM_ROOT_PASS}
  - name: ${VM_USERNAME}
    ssh_authorized_keys:
      - ssh-rsa ${SSH_PUB_KEY}
    groups: wheel
    ssh_pwauth: true
    hashed_passwd: ${VM_USER_PASS_HASH}
write_files:
  - path: /usr/local/etc/sudoers
    content: |
      %wheel ALL=(ALL) NOPASSWD: ALL
    append: true
EOF

}

while getopts "h:n:net:b:r:c:s:v" option; do
    case "${option}"
    in
        h)
            usage
            exit 0
            ;;
        n) VM_HOSTNAME=${OPTARG};;
        b) VM_BRIDGE_INT=${OPTARG};;
        r) VM_MEM_SIZE=${OPTARG};;
        c) VM_VCPUS=${OPTARG};;
        s) VM_DISK_SIZE=${OPTARG};;
        v) VERBOSE=1;;
        *)
            usage
            exit 1
            ;;
    esac
done


if [[ -z $VM_HOSTNAME ]]; then
    echo "ERROR: Host name is required"
    usage
    exit 1
fi

if [[ -n $VERBOSE ]]; then
    echo "Building ${VM_HOSTNAME} in $VM_IMAGE_DIR"
    set -xv
fi

if [[ -n $VM_BRIDGE_INT ]]; then
    LIBVIRT_NET_OPTION="model=virtio,bridge=${VM_BRIDGE_INT}"
fi

mkdir -p "$VM_BASE_DIR"/{images,xml,init,base,ssh}

## VM Base image
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
VM_BASE_IMAGE=$(echo "$selected" | jq -r .url)
VM_BASE_IMAGE_NAME=$(echo "$selected" | jq -r .origin_image_name)
VM_BOOT_TYPE=$(echo "$selected" | jq -r .boot_type)
VM_CHECKSUMS_URL=$(echo "$selected" | jq -r .md5sum)
CHECKSUM_TMP_FOLDER=$(mktemp)
curl -s -o "${CHECKSUM_TMP_FOLDER}" "${VM_CHECKSUMS_URL}"
VM_BASE_IMAGE_CHECKSUM=$(grep "${VM_BASE_IMAGE_NAME}" "${CHECKSUM_TMP_FOLDER}" | awk '{print $1}')

# Download base image
download_base_image
check_hash

echo "Creating a qcow2 image file ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img that uses the cloud image file ${VM_BASE_IMAGE_LOCATION} as its base"
if ! test -f "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img"; then
  #qemu-img create -b "${VM_BASE_DIR}/${VM_BASE_IMAGES}/${VM_OS_VARIANT}.qcow2" -f qcow2 -F qcow2 "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img" "${VM_DISK_SIZE}G"
  qemu-img convert \
    -O qcow2  \
    "${VM_BASE_IMAGE_LOCATION}" \
    "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img"
  qemu-img resize \
    "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img" \
    "${VM_DISK_SIZE}G"
  sudo chown -R $USER:libvirt-qemu "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img"
else
  echo "El fichero ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img ya existe. Elimina la VM con vm_delete.sh"
  exit 1
fi


# VM ssh keys gen
if [ -f "${VM_BASE_IMAGE}/ssh/${VM_HOSTNAME}" ]; then
  echo "Ya existe una clave ssh para la maquina ${VM_HOSTNAME}"
else
  ssh-keygen -t rsa -b 4096 -N '' -f "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}"
  chmod 600 ${VM_BASE_DIR}/ssh/${VM_HOSTNAME}.pub
  ssh-keygen -y -f "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}" > "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}".pub.txt
  SSH_PUB_KEY=$(cat "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}".pub.txt)
  rm "${VM_BASE_DIR}/ssh/${VM_HOSTNAME}".pub.txt
fi
#cloud-init VM meta-data
cat > "$VM_BASE_DIR/init/${VM_HOSTNAME}-meta-data" << EOF
instance-id: ${VM_HOSTNAME}
local-hostname: ${VM_HOSTNAME}
EOF
#cloud-init VM user-data
if [[ "$VM_OS_VARIANT" == "freebsd14.0" ]]; then
  gen_freebsd_user_data
  # genisoimage \
  # -output ${VM_BASE_DIR}/images/${VM_HOSTNAME}-cidata.iso \
  # -V cidata -r \
  # -J ${VM_BASE_DIR}/init/${VM_HOSTNAME}-user-data ${VM_BASE_DIR}/init/${VM_HOSTNAME}-meta-data
  # virt-install \
  # --name ${VM_HOSTNAME} \
  # --memory ${VM_MEM_SIZE} \
  # --vcpus="${VM_VCPUS}" \
  # --os-variant=${VM_OS_VARIANT} \
  # --disk ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img,device=disk,bus=virtio \
  # --disk path=${VM_BASE_DIR}/images/${VM_HOSTNAME}-cidata.iso,device=cdrom \
  # --network ${LIBVIRT_NET_OPTION} \
  # --autostart \
  # --import --noautoconsole \
  # --cloud-init root-password-generate=on,user-data=${VM_BASE_DIR}/init/${VM_HOSTNAME}-user-data 
else
  gen_linux_user_data
fi

VM_INSTALL_OPTS=""
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --name ${VM_HOSTNAME}" 
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --memory ${VM_MEM_SIZE}" 
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --vcpus ${VM_VCPUS}" 
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --os-variant=${VM_OS_VARIANT}" 
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --disk ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img,device=disk,bus=virtio" 
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --network ${LIBVIRT_NET_OPTION}"
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --autostart" 
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --import --noautoconsole" 
VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --cloud-init root-password-generate=on,user-data=${VM_BASE_DIR}/init/${VM_HOSTNAME}-user-data" 
if [ "$VM_BOOT_TYPE" = "UEFI" ]; then
    VM_INSTALL_OPTS="${VM_INSTALL_OPTS} --boot uefi"
fi
eval virt-install $VM_INSTALL_OPTS

virsh dumpxml "${VM_HOSTNAME}" > "${VM_BASE_DIR}/xml/${VM_HOSTNAME}.xml"
