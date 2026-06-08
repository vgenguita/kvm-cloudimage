#!/usr/bin/env bash
HAPROXY_URL="https://github.com/haproxytech/kubernetes-ingress/releases/download/v1.10.11/haproxy-ingress-controller_1.10.11_Linux_x86_64.tar.gz"
# Install HAProxy
apt update
apt install -y haproxy
systemctl stop haproxy
systemctl disable haproxy

# Allow the haproxy binary to bind to ports 80 and 443:
setcap cap_net_bind_service=+ep /usr/sbin/haproxy

# Install the HAProxy Kubernetes Ingress Controller
wget ${HAPROXY_URL} 1> /dev/null 2> /dev/null
mkdir ingress-controller
tar -xzvf haproxy-ingress-controller_1.10.11_Linux_x86_64.tar.gz -C ./ingress-controller
cp ./ingress-controller/haproxy-ingress-controller /usr/local/bin/
cp ingress_files/haproxy-ingress.service /lib/systemd/system/
systemctl enable haproxy-ingress
systemctl start haproxy-ingress

# Copy kube config to this server
# mkdir -p /root/.kube
# cp ingress_files/admin.conf /root/.kube/config
# chown -R root:root /root/.kube

# Install Bird
apt install bird2

# Copy over bird.conf
sudo cp ingress_files/bird.conf /etc/bird/
sudo systemctl enable bird
sudo systemctl restart bird