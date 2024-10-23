#!/bin/env bash
VM_HOSTNAME=
VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/vms"}
VM_DISK_SIZE=20
VM_DISK_FORMAT=qcow2
VM_MEM_SIZE=2048
VM_VCPUS=2
VM_BASE_IMAGE=
VM_OS_VARIANT=
VM_USERNAME="user"
VM_BRIDGE_INT=
VM_NET_USED="default"
LIBVIRT_NET_OPTION="network=$VM_NET_USED,model=e1000"
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
  source < env_scripts/older_os.sh
else 
  source > env_scripts/newer_os.sh
fi

case $answer in
          [1]* )  VM_OS_VARIANT=${GUEST_OS_TYPE_DEBIAN}
                  VM_BASE_IMAGE='https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2'
                  break;;
          [2]* )  VM_OS_VARIANT='ubuntu20.04'
                  VM_BASE_IMAGE='https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img'
                  break;;
          [3]* )  VM_OS_VARIANT='ubuntu22.04'
                  VM_BASE_IMAGE='https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img'
                  break;;
          [4]* )  VM_OS_VARIANT='ubuntu24.04'
                  VM_BASE_IMAGE='https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img'
                  break;;
          [5]* )  VM_OS_VARIANT='freebsd14.0'
                  VM_BASE_IMAGE='https://download.freebsd.org/releases/VM-IMAGES/14.0-RELEASE/amd64/Latest/FreeBSD-14.0-RELEASE-amd64.qcow2.xz'
                  break;;
          * ) echo "Please answer 1,2,3,4,5.";;
      esac
  done
download_base_image()
{
if ! test -f "${VM_BASE_DIR}/base/$VM_OS_VARIANT.qcow2"; then
  if [[ "$VM_OS_VARIANT" == "freebsd14.0" ]]; then
    VM_DISK_FORMAT=".qcow2.xz"
    wget -v -O "${VM_BASE_DIR}/base/$VM_OS_VARIANT.${VM_DISK_FORMAT}" ${VM_BASE_IMAGE}
    cd ${VM_BASE_DIR}/base/
    xz -d $VM_OS_VARIANT.${VM_DISK_FORMAT} 
    cd -
  else 
    wget -v -O "${VM_BASE_DIR}/base/$VM_OS_VARIANT.${VM_DISK_FORMAT}" ${VM_BASE_IMAGE}
  fi
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
if [ -n "$VM_BASE_IMAGE" ] && [ -f "$VM_BASE_IMAGE" ]; then
download_base_image  
else
  while true; do
      read -r -p $'Select VM OS:\n 1.Debian12\n 2.Ubuntu 20.04\n 3.Ubuntu 22.04\n 4.Ubuntu 24.04 \n 5.FreeBSD 14\n' -n1 answer
      case $answer in
          [1]* )  VM_OS_VARIANT='debian11'
                  VM_BASE_IMAGE='https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2'
                  break;;
          [2]* )  VM_OS_VARIANT='ubuntu20.04'
                  VM_BASE_IMAGE='https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img'
                  break;;
          [3]* )  VM_OS_VARIANT='ubuntu22.04'
                  VM_BASE_IMAGE='https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img'
                  break;;
          [4]* )  VM_OS_VARIANT='ubuntu24.04'
                  VM_BASE_IMAGE='https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img'
                  break;;
          [5]* )  VM_OS_VARIANT='freebsd14.0'
                  VM_BASE_IMAGE='https://download.freebsd.org/releases/VM-IMAGES/14.0-RELEASE/amd64/Latest/FreeBSD-14.0-RELEASE-amd64.qcow2.xz'
                  break;;
          * ) echo "Please answer 1,2,3,4,5.";;
      esac
  done
  download_base_image
fi


echo "Creating a qcow2 image file ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img that uses the cloud image file ${VM_BASE_DIR}/base/$VM_OS_VARIANT.${VM_DISK_FORMAT} as its base"
if ! test -f "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img"; then
    qemu-img create -b "${VM_BASE_DIR}/base/${VM_OS_VARIANT}.qcow2" -f qcow2 -F qcow2 "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img" "${VM_DISK_SIZE}G"
else
  echo "El fichero ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img ya existe"
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

  virt-install \
  --name ${VM_HOSTNAME} \
  --memory ${VM_MEM_SIZE} \
  --vcpus="${VM_VCPUS}" \
  --os-variant=${VM_OS_VARIANT} \
  --disk ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img,device=disk,bus=virtio \
  --network ${LIBVIRT_NET_OPTION} \
  --autostart \
  --import --noautoconsole \
  --cloud-init root-password-generate=on,user-data=${VM_BASE_DIR}/init/${VM_HOSTNAME}-user-data 
# cloud-localds \
#   ${VM_BASE_DIR}/images/${VM_HOSTNAME}.iso \
#   ${VM_BASE_DIR}/init/${VM_HOSTNAME}-user-data
virsh dumpxml "${VM_HOSTNAME}" > "${VM_BASE_DIR}/xml/${VM_HOSTNAME}.xml"

if [ -n $VERBOSE ]; then
    set +xv
fi
# Show running VMs
virsh list
