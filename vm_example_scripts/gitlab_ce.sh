#!/bin/sh
#SOURCE: https://about.gitlab.com/install/#debian
export DEBIAN_FRONTEND=noninteractive 
NET_DEVICE='enp1s0'
GITLAB_URL=$(ip -o -4 addr list ${NET_DEVICE} | awk '{print $4}' | cut -d/ -f1)
#Base dependencies
sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates perl
#OPTIONAL: postfix
#sudo apt-get install -y postfix
#Add gitlab repo
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
sudo EXTERNAL_URL="${GITLAB_URL}" apt-get install gitlab-ee