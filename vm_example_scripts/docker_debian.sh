#!/usr/bin/env bash
# SOURCE: https://docs.docker.com/engine/install/debian/
#         https://docs.docker.com/engine/install/linux-postinstall/

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Remove old conflicting packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done

# Add Docker's official GPG key
apt-get update
apt-get -y install ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources
# shellcheck disable=SC2027,SC2046  # We handle word splitting safely here
# shellcheck source=/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update and install Docker
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
usermod -aG docker "${USER}"

# Refresh group membership (optional, user may need to log out)
newgrp docker