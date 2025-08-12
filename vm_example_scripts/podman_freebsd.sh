#!/usr/bin/env sh
# Source: https://podman.io/docs/installation#installing-on-freebsd-140

# Variables
LINE='fdesc   /dev/fd         fdescfs         rw      0       0'
FSTAB="/etc/fstab"
FD_MOUNTPOINT="/dev/fd"
FSTYPE="fdescfs"
SERVICE_NAME='linux'

# Enable Linux compatibility
sysrc linux_enable=YES

# Start the service if not running
if ! service "${SERVICE_NAME}" status >/dev/null 2>&1; then
    if ! service "${SERVICE_NAME}" start; then
        echo "Error: Cannot start ${SERVICE_NAME}." >&2
        exit 1
    fi
    echo "Service ${SERVICE_NAME} started"
fi

# Add fdescfs to /etc/fstab if not present
if ! grep -q 'fdesc[[:space:]]\+/dev/fd[[:space:]]\+fdescfs[[:space:]]\+rw[[:space:]]\+0[[:space:]]\+0' "$FSTAB"; then
    printf '%s\n' "$LINE" | tee -a "$FSTAB" > /dev/null
fi

# Install and enable Podman
pkg install -y podman-suite
service podman enable

# Mount fdescfs if not already mounted
if ! mount | grep -w "${FD_MOUNTPOINT}" | grep -q "$FSTYPE"; then
    mount -t fdescfs fdesc /dev/fd
fi

# Configure pf firewall
cp /usr/local/etc/containers/pf.conf.sample /etc/pf.conf
sed -i '' 's/ix0/vtnet0/g' /etc/pf.conf

# Enable pf at boot
if ! grep -q 'pf_load="YES"' "/boot/loader.conf"; then
    echo 'pf_load="YES"' | tee -a /boot/loader.conf > /dev/null
fi

# Load pf module and enable local filtering
kldload pf
sysctl net.pf.filter_local=1

if ! grep -q 'net.pf.filter_local=1' "/etc/sysctl.conf.local"; then
    echo 'net.pf.filter_local=1' | tee -a /etc/sysctl.conf.local > /dev/null
fi

service pf enable
service pf restart

# Configure storage backend
if pgrep -x zfskern >/dev/null 2>&1; then
    zfs create -o mountpoint=/var/db/containers zroot/containers
else
    sed -I .bak -e 's/driver = "zfs"/driver = "vfs"/' /usr/local/etc/containers/storage.conf
fi