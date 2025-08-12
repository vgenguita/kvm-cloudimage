#!/usr/bin/env bash
#SOURCE:    https://docs.docker.com/engine/install/fedora/
#           https://docs.docker.com/engine/install/linux-postinstall/

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

dnf -y remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
dnf -y install dnf-plugins-core
dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "$USER"
echo "To use docker execute :"
echo "newgrp docker"