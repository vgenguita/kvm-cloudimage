#Untaint node
## We must untaint the node to allow pods to be deployed to our single-node cluster. Otherwise, your pods will be stuck in a pending state.
#kubectl taint nodes --all node-role.kubernetes.io/master-
##Uncoment when single node
#kubectl taint nodes --all node-role.kubernetes.io/control-plane-
#Flannel
##https://github.com/flannel-io/flannel
# kubectl create ns kube-flannel
# kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged
# helm repo add flannel https://flannel-io.github.io/flannel/
# helm install flannel --set podCidr="10.244.0.0/16" --namespace kube-flannel flannel/flannel
#Callico
helm repo add projectcalico https://docs.tigera.io/calico/charts
kubectl create namespace tigera-operator
cat > values.yaml <<EOF
installation:
  cni:
    type: Calico
  calicoNetwork:
    bgp: Disabled
    ipPools:
    - cidr: 10.244.0.0/16
      encapsulation: VXLAN
EOF
helm install calico projectcalico/tigera-operator --version v3.27.2 -f values.yaml --namespace tigera-operator
rm values.yaml
#Certmanager
# helm repo add jetstack https://charts.jetstack.io
# helm repo update
# helm install \
#   cert-manager jetstack/cert-manager \
#   --namespace cert-manager \
#   --create-namespace \
#   --version v1.13.3 \
#   --set installCRDs=true
#Metallb
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
#Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/baremetal/deploy.yaml