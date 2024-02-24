#!/bin/bash
VM_BASE_DIR=${VM_BASE_DIR:-"${HOME}/vms"}
VM_USER="user"
VM=$1
VM_IP=''
SCRIPT=''
VM_DISTRO=''
VM_VERSION=''
usage() {
  cat << EOF
USO: $0 VM

Este script instala algunos programas en la VM seleccionada

EOF
}

# Función para obtener la dirección IP de la máquina virtual
get_vm_ip_address() {
  local VM="$1"

  # Obtener la dirección MAC de la interfaz de red
  MAC_VM=$(virsh domiflist "$VM" | awk '{ print $5 }' | tail -2 | head -1)
  if [[ -z "$MAC_VM" ]]; then
    echo "Error: No se pudo encontrar la dirección MAC para '$VM'"
    return 1
  fi

  # Obtener la dirección IP a partir de la dirección MAC
  VM_IP_ADDRESS=$(arp -a | grep "$MAC_VM" | awk '{ print $2 }' | sed 's/[()]//g')
  if [[ -z "$VM_IP_ADDRESS" ]]; then
    echo "Error: No se pudo encontrar la dirección IP para la dirección MAC '$MAC_VM'"
    return 1
  fi

  echo "$VM_IP_ADDRESS"
}

obtener_info_vm() {
  # Obtener el ID del sistema operativo
  # Obtener el ID del sistema operativo
  OS_ID=$(grep -o 'id="[^"]*"' "$1" | tr -d '"' | awk '{print $1}')

  # Eliminar el protocolo y el dominio del ID
  OS_ID=$(echo "$OS_ID" | cut -d '/' -f 2-)
  echo $OS_ID
  # Convertir la URL a un nombre de distribución y versión
  VM_DISTRO=$(echo "$OS_ID" | awk -F '/' '{print $3}')
  VM_VERSION=$(echo "$OS_ID" | awk -F '/' '{print $4}')

}

# Obtener el nombre del host de la máquina virtual
VM="$1"

if [[ -z "$VM" ]]; then
  usage
  exit 1
fi

# Obtener la dirección IP de la máquina virtual
VM_IP=$(get_vm_ip_address "$VM")
obtener_info_vm ${VM_BASE_DIR}/xml/${VM}.xml
while true; do
      read -r -p $'Select software to install:\n 1.Docker\n 2.Gitlab CE\n 3.Gitlab runner\n 4.Kubernetes Single cluster\n' -n1 answer
      case $answer in
          [1]* )  
                  if [[ "$VM_DISTRO" == "debian" ]]; then 
                    SCRIPT='../vm_example_scripts/docker_debian.sh'
                  elif [[ "$VM_DISTRO" == "ubuntu" ]]; then  
                    SCRIPT='../vm_example_scripts/docker_ubuntu.sh'
                  fi
                  break;;
          [2]* )  SCRIPT='../vm_example_scripts/gitlab_ce.sh'
                  break;;
          [3]* )  SCRIPT='../vm_example_scripts/gitlab_runner.sh'
                  break;;       
          [4]* )  cd ../vm_example_scripts/
                  ./k8s.sh $VM 
                  break;;
          * ) echo "Please answer 1,2,3 or 4.";;
      esac
done
if [[ -z "$SCRIPT" ]]; then
  exit 0
else
   ssh -i ${VM_BASE_DIR}/ssh/${VM} -l${VM_USER} ${VM_IP} "bash -s" -- < ${SCRIPT}
fi
