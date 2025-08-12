#!/usr/bin/env bash
# SOURCE: https://docs.docker.com/engine/install/ubuntu/
#         https://docs.docker.com/engine/install/linux-postinstall/

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Remove old or conflicting packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done

# Install prerequisites
apt-get update
apt-get install -y ca-certificates curl gnupg

# Create keyrings directory and add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
# shellcheck source=/dev/null
. /etc/os-release
ARCH=$(dpkg --print-architecture)
CODENAME="$VERSION_CODENAME"

echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update and install Docker
apt-get update
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Add user to docker group
usermod -aG docker "$USER"

# Refresh group membership
echo "Docker installation completed."
echo "To use Docker without sudo, run:"
echo "    newgrp docker"
echo "Or log out and back"