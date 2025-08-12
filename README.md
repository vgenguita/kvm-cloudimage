# kvm-cloudimage

Use cloud images on bare metal with libvirt/KVM.

Currently, the following base operating systems are supported for guest VMs:
- Debian 12
- Ubuntu 20.04
- Ubuntu 22.04
- FreeBSD 14.3 with UFS filesystem
- FreeBSD 14.2 with ZFS filesystem
- OpenBSD 7.7

## Pre-requisites

The following tools must be installed on the host system:
* `openssh`
* `arp`
* `wget`
* `curl`
* `libvirt` 

To create OpenBSD images, you will also need:

* `python3`
* `sudo`
* `signify` (Debian: `signify-openbsd` and `signify-openbsd-keys`)
* `qemu-system-x86_64`

## Links and credits
Livbirt host installation
- [Debian guide](https://wiki.debian.org/KVM)
- [Ubuntu guide](https://documentation.ubuntu.com/server/how-to/virtualisation/libvirt/)
- [Fedora guide](https://docs.fedoraproject.org/en-US/quick-docs/virtualization-getting-started/)

Inspirational sites for the project 
- [https://blog.programster.org/create-debian-12-kvm-guest-from-cloud-image](https://blog.programster.org/create-debian-12-kvm-guest-from-cloud-image)
- [https://earlruby.org/2023/02/quickly-create-guest-vms-using-virsh-cloud-image-files-and-cloud-init/](https://earlruby.org/2023/02/quickly-create-guest-vms-using-virsh-cloud-image-files-and-cloud-init/)
- [https://sumit-ghosh.com/posts/create-vm-using-libvirt-cloud-images-cloud-init/)](https://sumit-ghosh.com/posts/create-vm-using-libvirt-cloud-images-cloud-init/)

For OpenBSD images with cloud-init support, this project uses: [hcartiaux's openbsd-cloud-image](https://github.com/hcartiaux/openbsd-cloud-image.git)

## Preparing the Host

1. Configure the [variables](env_scripts/common.sh) file (`env_scripts/common.sh`).  
   It is recommended to place this directory in your home folder to avoid libvirt permission issues.

2. Run the installation script: install.sh

### AppArmor exception (if needed) 

If AppArmor is blocking libvirtd, disable the profile temporarily: 

```shell
ln -s /etc/apparmor.d/usr.sbin.libvirtd /etc/apparmor.d/disable/
apparmor_parser -R /etc/apparmor.d/usr.sbin.libvirtd
```


<!-- ### Create bridge network

```shell
sudo virsh --connect qemu:///session net-define /dev/stdin << EOF
<network>
  <name>bridged-network</name>
  <forward mode='bridge'/>
  <bridge name='brbackend' />
</network>
EOF
``` -->
## Command Usage
### Command help
```shell
NAME
  ./vm_manage.sh

USAGE
    Usage:  ./vm_manage.sh create -n NAME [-b BRIDGE] [-r RAM] [-c VCPUS] [-s DISK] [-v]
            ./vm_manage.sh delete NAME
            ./vm_manage.sh info NAME
            ./vm_manage.sh connect NAME
            ./vm_manage.sh install NAME
            ./vm_manage.sh list

ACTIONS
  create     Create a new virtual machine
  delete     Delete a virtual machine
  list       List all defined virtual machines
  info       Show information about a virtual machine
  connect    Connect to the console of a virtual machine
  install    Install specific software into an existing VM

OPTIONS
  -h         Show this help message
  -n NAME    Host name (required)
  -b BRIDGE  Bridge interface name
  -r RAM     RAM in MB (default: 1024)
  -c VCPUS   Number of VCPUs (default: 1)
  -s DISK    Disk size in GB (default: 10)
  -v         Verbose mode
  
AUTHOR
  Victor Gracia Enguita <victor@burufalla.ovh>

COPYRIGHT
  This is free software; see the source for copying conditions.
```

### Create VM
Using default values:
```shell
./vm_manage.sh create -ntestMachine
```
__Note__: Default values can be customized in the [env_scripts/common.sh](env_scripts/common.sh) file.


With custom specifications: 
```shell
./vm_manage.sh create -ntestMachine -r4098 -c4 -s100
```
This creates a VM with 4096 MB of RAM, 4 vCPUs, and 100 GB of disk space. 

## List VMs
```shell
./vm_manage.sh list
 Id   Nombre       Estado
-------------------------------
 7    debianTest   ejecutando
 8    ubuntuTest   ejecutando
```
## Connect to an VM
```shell
./vm_manage.sh connect debianTest
```

## Get ip of VM

```shell
./vm_manage.sh info ubuntuTest
192.168.122.234
```

## Delete VMs

Use as parameter machine name
```shell
./vm_dmanage.sh delete ubuntuTest
Are you sure you want to remove the VM 'ubuntuTest' (y/N)? y
Domain 'ubuntuTest' destroyed

Domain 'ubuntuTest' has been undefined

VM 'ubuntuTest' removed successfully.
```
## Install software on VM


`./vm_manage.sh install VM_NAME`

Example:

```shell
./vm_manage.sh install Debian
Select software to install:
--------------
 1. Docker
 2. Podman
 3. Gitlab CE
 4. Gitlab Runner
Enter your choice [1-4]: 
```

## TODO

  - Maybe add more BSD flavours guests support
  - add non debian linux derivatives guests support
<!-- ./vm_create.sh: línea 52: mkpasswd: orden no encontrada
./vm_create.sh: línea 259: virt-install: orden no encontrada
./vm_create.sh: línea 261: virsh: orden no encontrada
qemu-img wget curl  arp
sudo apt install --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system whois virtinst net-tools
sudo chmod 750 /home/victor
sudo usermod -a -G libvirt $(whoami)
sudo usermod --append --groups earl libvirt-qemu -->

