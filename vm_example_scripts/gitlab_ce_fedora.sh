#!/usr/bin/env bash
#Source: https://docs.gitlab.com/install/package/almalinux/?tab=Community+Edition

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

NET_DEVICE='enp1s0'
GITLAB_URL=$(ip -o -4 addr list ${NET_DEVICE} | awk '{print $4}' | cut -d/ -f1)

#Enable sshd. enabled on cloud-image by default
#systemctl enable --now sshd
#Set firewall rules
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ssh
systemctl reload firewalld
#Add repo
curl "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh" | bash
#Install Gitlab CE
EXTERNAL_URL="${GITLAB_URL}" dnf install gitlab-ce