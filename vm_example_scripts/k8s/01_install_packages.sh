#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
NODE_IP=$(ip -4 addr show ${if} | grep "inet" | head -1 | awk '{print $2}' | cut -d/ -f1)
DEVICE="enp1s0"
cd install_packages/
echo "## Installing essential tools"
sh 01-install-essential-tools.sh
echo "## Prepare host"
sh 02-allow-bridge-nf-traffic.sh
echo "## Install containerd"
sh 03-install-containerd.sh
echo "## Install kubeadm"
sh 04-install-kubeadm.sh ${DEVICE}
sh 05-update-kubelet-config.sh ${DEVICE}
echo "## Initialising single node"
sh $PWD/vm_files/master.sh ${NODE_IP}