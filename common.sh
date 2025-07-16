#!/bin/env bash
OS_JSON_FILE="os_options.json"
#VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/.local/share/libvirt"}
#VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/var/lib/libvirt"}
VM_BASE_DIR="${HOME}/vms"
VM_BASE_IMAGES="base"
VM_USERNAME="user"
VM_IMAGE_PATH="${VM_BASE_DIR}/images/$1.img"
CI_IMAGE_PATH="${VM_BASE_DIR}/images/$1-cidata.iso"
