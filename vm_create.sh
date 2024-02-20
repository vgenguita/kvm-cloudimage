#!/bin/bash

# Variables
VM_HOSTNAME=
VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/vms"}
VM_DISK_SIZE=20
VM_MEM_SIZE=2048
VM_VCPUS=2
VM_BASE_IMAGE=
VM_OS_VARIANT=
VM_USERNAME="user"
# Functions
usage()
{
cat << EOF
usage: $0 options

Quickly create guest VMs using cloud image files and cloud-init.

OPTIONS:
   -h      Show this message
   -n      Host name (required)
   -r      RAM in MB (defaults to ${VM_MEM_SIZE})
   -c      Number of VCPUs (defaults to ${VM_VCPUS})
   -s      Amount of storage to allocate in GB (defaults to ${VM_DISK_SIZE})
   -v      Verbose
EOF
}

download_base_image()
{
if ! test -f "$HOME/vms/base/$VM_OS_VARIANT.qcow2"; then
  wget -v -O "$HOME/vms/base/$VM_OS_VARIANT.qcow2" "$VM_BASE_IMAGE"
fi
}

while getopts "h:n:r:c:s:v" option; do
    case "${option}"
    in
        h)
            usage
            exit 0
            ;;
        n) VM_HOSTNAME=${OPTARG};;
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

mkdir -p "$VM_BASE_DIR"/{images,xml,init,base,ssh}

## VM Base image
if [ -n "$VM_BASE_IMAGE" ] && [ -f "$VM_BASE_IMAGE" ]; then
download_base_image  
else
  while true; do
      read -r -p $'Select VM OS:\n 1.Debian12\n 2.Ubuntu 20.04\n 3.Ubuntu22.04\n 4.FreeBSD 14\n' -n1 answer
      case $answer in
          [1]* )  VM_OS_VARIANT='debian12'
                  VM_BASE_IMAGE='https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2'
                  break;;
          [2]* )  VM_OS_VARIANT='ubuntu20.04'
                  VM_BASE_IMAGE='https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img'
                  break;;
          [3]* )  VM_OS_VARIANT='ubuntu22.04'
                  VM_BASE_IMAGE='https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img'
                  break;;
          [4]* )  VM_OS_VARIANT='freebsd13.2'
                  VM_BASE_IMAGE='https://download.freebsd.org/ftp/snapshots/VM-IMAGES/14.0-STABLE/amd64/20240215/FreeBSD-14.0-STABLE-amd64-20240215-090674a3dbf8-266693.qcow2.xz'
                  break;;
          * ) echo "Please answer 1,2,3,4.";;
      esac
  done
  download_base_image
fi

echo "Creating a qcow2 image file ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img that uses the cloud image file ${IMG_FQN} as its base"
if ! test -f "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img"; then
  qemu-img create -b "$HOME/vms/base/${VM_OS_VARIANT}.qcow2" -f qcow2 -F qcow2 "${VM_BASE_DIR}/images/${VM_HOSTNAME}.img" "${VM_DISK_SIZE}G"
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
cat > "$VM_BASE_DIR/init/${VM_HOSTNAME}-user-data" << EOF
#cloud-config

hostname: ${VM_HOSTNAME}
# manage_etc_hosts: false
ssh_pwauth: false
disable_root: true
users:
- name: ${VM_USERNAME}
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  lock-passwd: false
  ssh_authorized_keys:
    - ${SSH_PUB_KEY}
EOF

virt-install \
  --name ${VM_HOSTNAME} \
  --memory ${VM_MEM_SIZE} \
  --vcpus="${VM_VCPUS}" \
  --os-type linux \
  --os-variant ${VM_OS_VARIANT} \
  --cloud-init root-password-generate=on,user-data=${VM_BASE_DIR}/init/${VM_HOSTNAME}-user-data \
  --disk ${VM_BASE_DIR}/images/${VM_HOSTNAME}.img,device=disk,bus=virtio \
  --network network=default,model=virtio \
  --autostart \
  --import --noautoconsole

virsh dumpxml "${VM_HOSTNAME}" > "${VM_BASE_DIR}/xml/${VM_HOSTNAME}.xml"

if [ -n $VERBOSE ]; then
    set +xv
fi
# Show running VMs
virsh list