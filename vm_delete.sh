#!/bin/env bash

# Function for usage message
usage() {
  cat << EOF
Usage: $0 vm_name

This script removes a virtual machine managed by virsh.

EOF
}
VM_BASE_DIR="${VM_BASE_DIR:-${HOME}/vms}"
VM_IMAGE_PATH="${VM_BASE_DIR}/images/$1.img"
CI_IMAGE_PATH="${VM_BASE_DIR}/images/$1-cidata.iso"

# Validate VM name argument
if [[ -z "$1" ]]; then
  usage
  exit 1
fi

# Check if VM exists
if [[ -f "$VM_IMAGE_PATH" ]]; then
  # Safely remove the VM with confirmation
  read -p "Are you sure you want to remove the VM '$1' (y/N)? " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Attempt to stop the VM before deleting
    virsh destroy "$1" 2>/dev/null || true
    # Delete VM definition and associated images
    virsh undefine "$1" 2>/dev/null || true
    rm -fv "$VM_IMAGE_PATH" "$CI_IMAGE_PATH"
    rm ${VM_BASE_DIR}/xml/$1.xml
    rm ${VM_BASE_DIR}/ssh/$1*
    rm ${VM_BASE_DIR}/init/$1-user-data
    rm ${VM_BASE_DIR}/init/$1-meta-data
  else
    echo "VM removal cancelled."
  fi
else
  # Handle case where VM image is not found
  echo "Cannot find VM image file '$VM_IMAGE_PATH'. No action taken."
fi