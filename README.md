# kvm-cloudimage
Use cloud images on baremetal using libvirt/kvm

## Pre-requisites
- openssh
- mkpass (whois)
- arp

## Links
- [https://blog.programster.org/create-debian-12-kvm-guest-from-cloud-image](https://blog.programster.org/create-debian-12-kvm-guest-from-cloud-image)
- [https://earlruby.org/2023/02/quickly-create-guest-vms-using-virsh-cloud-image-files-and-cloud-init/](https://earlruby.org/2023/02/quickly-create-guest-vms-using-virsh-cloud-image-files-and-cloud-init/)
- [https://sumit-ghosh.com/posts/create-vm-using-libvirt-cloud-images-cloud-init/)](https://sumit-ghosh.com/posts/create-vm-using-libvirt-cloud-images-cloud-init/)

## Preparing host

### Create bridge network

```shell
sudo virsh --connect qemu:///session net-define /dev/stdin << EOF
<network>
  <name>bridged-network</name>
  <forward mode='bridge'/>
  <bridge name='brbackend' />
</network>
EOF
```

#### AppArmor exception

```shell
ln -s /etc/apparmor.d/usr.sbin.libvirtd /etc/apparmor.d/disable/
apparmor_parser -R /etc/apparmor.d/usr.sbin.libvirtd
```

## Creating VMs
### Usage
```shell
usage: ./vm_create.sh options

Quickly create guest VMs using cloud image files and cloud-init.

OPTIONS:
   -h      Show this message
   -n      Host name (required)
   -b      bridge interface name (bridge network is used)
   -r      RAM in MB (defaults to 2048)
   -c      Number of VCPUs (defaults to 2)
   -s      Amount of storage to allocate in GB (defaults to 20)
   -v      Verbose
```

The only required parameter is the hostname, but you can also set RAM size (in MB), number of VCPUs or storage size (in GB), if these parameters are not set, default values will used:
- RAM: 20248MB
- VCPUs: 2
- DISK: 20GB

Actually, you can select these base OS for Guests
- Debian 12
- Ubuntu 20.04
- Ubuntu 22.04
- FreeBSD 14.1 

### Examples 
```shell
./vm_create.sh -ntestMachine
```
A VM will ve created with default values

```shell
./vm_create.sh -ntestMachine -r4098 -c4 -s100
```
A VM will be created with 4098 MB of RAM, 4 vCPUs and 100Gb of storage

#### FreeBSD VMs

FreeBSD with cloud-init are now supported!! Just wait a little time to have the VM fully initialized (check it with virt-manager or serial connection manually)

## List VMs
```shell
./vm_list.sh 
 Id   Nombre       Estado
-------------------------------
 7    debianTest   ejecutando
 8    ubuntuTest   ejecutando
```
## Connect to an VM
```shell
./vm_connect.sh debianTest
```

## Get ip of VM

Use as parameter machine name
```shell
./vm_get_ip.sh ubuntuTest
192.168.122.234
```

## Delete VMs

Use as parameter machine name
```shell
./vm_delete.sh ubuntuTest
Are you sure you want to remove the VM 'ubuntuTest' (y/N)? y
Domain 'ubuntuTest' destroyed

Domain 'ubuntuTest' has been undefined

VM 'ubuntuTest' removed successfully.
```
## TODO

- FreeBSD support is still in progress
- Check if used commands are available
./vm_create.sh: línea 52: mkpasswd: orden no encontrada
./vm_create.sh: línea 259: virt-install: orden no encontrada
./vm_create.sh: línea 261: virsh: orden no encontrada
qemu-img wget curl mkpass arp
sudo apt install --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system whois virtinst net-tools
sudo chmod 750 /home/victor
sudo usermod -a -G libvirt $(whoami)
sudo usermod --append --groups earl libvirt-qemu

- Refactoring variables, functions and scripts calls for legibility and maintenance
- add script for create default files (network, variables etc)
