#!/bin/env bash
DISTRO=""

#VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/.local/share/libvirt"}
#VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/var/lib/libvirt"}
VM_BASE_DIR="${HOME}/vms"
VM_BASE_IMAGES="base"
VM_DISK_EXTENSION="img"
VM_NETWORK_NAT="vmnetwork"
VM_NETWORK_HOSTONLY="host-only"
VM_NETWORK_TYPE="nat"
VM_USERNAME="user"
VM_SOFT="";
VM_IMAGE_PATH="${VM_BASE_DIR}/images/$1.img"
CI_IMAGE_PATH="${VM_BASE_DIR}/images/$1-cidata.iso"
LIBVIRT_NET_MODEL="virtio"
LIBVIRT_NET_OPTION="network=${VM_NETWORK_NAT},model=${LIBVIRT_NET_MODEL}"
OS_JSON_FILE="files/os_options.json"
OS_JSON_FILE_INSTALL="files/software.json"

# REPO_BRANCH="main"
# REPO_SOURCE="https://raw.githubusercontent.com/vgenguita/kvm-cloudimage/refs/heads/${REPO_BRANCH}/env_scripts/"
