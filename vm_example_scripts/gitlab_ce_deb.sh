#!/usr/bin/env bash
#SOURCE: https://about.gitlab.com/install/#debian

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive 
NET_DEVICE='enp1s0'
GITLAB_URL=$(ip -o -4 addr list ${NET_DEVICE} | awk '{print $4}' | cut -d/ -f1)
#Base dependencies
apt-get update
apt-get install -y curl openssh-server ca-certificates perl
#OPTIONAL: postfix
#apt-get install -y postfix
#Add gitlab repo
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
EXTERNAL_URL="${GITLAB_URL}" apt-get install gitlab-ee