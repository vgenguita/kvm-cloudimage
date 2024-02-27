#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
NODE_IP=$(ip -4 addr show ${DEVICE} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)
DEVICE="enp1s0"
cd install_packages/
echo "## Installing essential tools"
bash 01-install-essential-tools.sh
echo "## Prepare host"
bash 02-allow-bridge-nf-traffic.sh
echo "## Install containerd"
bash 03-install-containerd.sh
echo "## Install kubeadm"
bash 04-install-kubeadm.sh 
bash 05-update-kubelet-config.sh ${DEVICE}
echo "## Initialising single node"
#bash $PWD/vm_files/master.sh ${NODE_IP}
#bash $PWD/vm_files/node.sh ${NODE_IP}