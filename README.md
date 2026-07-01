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

2. Run the installation script: `install.sh`

## Networking

Two networks are installed when you run `install.sh`:

| Name  | Type     |DCHP Range   |Default route   |Host device   |  
| ----- | -------- |-------------|----------------|--------------|
| vmnetwork | NAT  |192.168.100.100 - 254| 192.168.100.1| virb1|
| host-only | Isolated Network  |-|-| -|

**Table 1:** Default Available Networks

You can network names changing on [env_scripts/common.sh](env_scripts/common.sh)  
```
VM_NETWORK_HOSTONLY="host-only"
VM_USERNAME="user"
```

You can create a VM with isolated network but an extra interface with NAT network if added, because when guest is initialized, it get updated and some packages are installed (dependend on linux-user-metadata). You can delete NAT interface after VM guest is initialized.

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

# Scripts
## k3s kubernetes cluster
# Kubernetes k3s
## Arquitecture
```
                  ┌────────────────────────┐
                  │  LAN: 192.168.10.0/24  │
                  └───────────┬────────────┘
                              │
                     ┌────────▼────────┐
                     │  VM: HAProxy    │
                     │  ┌───────────┐  │
                     │  │ eth0: LAN │  │ ← 192.168.10.50
                     │  │ eth1: K8S │  │ ← 10.10.10.1 (gateway)
                     │  └───────────┘  │
                     └────────┬────────┘
                                │
               ┌────────────────┴────────────────┐
               │  Red NAT aislada: 10.10.10.0/24 │
               │  (libvirt virtual network)      │
               └────────────────┬────────────────┘
                                │
         ┌──────────────────────┼─────────────────────┐
         │                      │                     │
┌────────▼────────┐    ┌────────▼────────┐   ┌────────▼────────┐
│ Control Plane   │    │   Worker-1      │   │   Worker-2      │
│ eth0:10.10.10.11│    │ eth0:10.10.10.12│   │ eth0:10.10.10.13│
└─────────────────┘    └─────────────────┘   └─────────────────┘
```

## TODO

  - Maybe add more BSD flavours guests support
  - add non debian linux derivatives guests support
### When source images changes md5 fails
The current process is:
  - Select an operating system
  - If image for the selected OS is already installed, it is not downloaded again
  - Compare checksum for expected downloaded file and existent image and fails because source image has changed.
  
```shell
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  7708  100  7708    0     0  25708      0 --:--:-- --:--:-- --:--:-- 25779
ERROR: MD5 checksum does NOT match!
Expected: 1882f2d0debfb52254db1b0fc850d222fa68470a644a914d181f744ac1511a6caa1835368362db6dee88504a13c726b3ee9de0e43648353f62e90e075f497026
Got:      8f5c54d654b53951430b404efc3043b425cf2214467d5bf33d6c5157fa47c8fe4a1a2abf603050dafc7e54f57e9685f0d59a6c0d09d0cb2b7fcec75561c0df6f
 ✘  ~/dev/git/kvm-cloudimage   develop ±   cd /home/victor/dev/git

```
# Fedora
```shell
curl -O https://fedoraproject.org/fedora.pgp

curl -O https://fedoraproject.org/fedora.gpg

curl -Ohttps://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-44-1.7-x86_64-CHECKSUM

sq verify --cleartext --signer-file ./fedora.pgp \
                  Fedora-Cloud-44-1.7-x86_64-CHECKSUM \
                  | sha256sum -c --ignore-missing
gpgv --keyring ./fedora.gpg --output - \
                  Fedora-Cloud-44-1.7-x86_64-CHECKSUM \
                  | sha256sum -c --ignore-missing

#      Alternatively, if you just want to test for unintentional file corruption, you can skip the OpenPGP verification. The SHA256 checksum for this download should be:

28680fe5b371a5a82ebf43a31926e086a168e59949d03969c5093e7071f90b7f                 
```

# Debian
```shell
install debian-keyring
/usr/share/keyrings/debian-role-keys.pgp


curl -O https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS
gpgv --keyring .//usr/share/keyrings/debian-role-keys.pgp --output - \
                  Fedora-Cloud-44-1.7-x86_64-CHECKSUM \
                  | sha256sum -c --ignore-missing
```

<!-- ./vm_create.sh: línea 52: mkpasswd: orden no encontrada
./vm_create.sh: línea 259: virt-install: orden no encontrada
./vm_create.sh: línea 261: virsh: orden no encontrada
qemu-img wget curl  arp
sudo apt install --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system whois virtinst net-tools
sudo chmod 750 /home/victor
sudo usermod -a -G libvirt $(whoami)
sudo usermod --append --groups earl libvirt-qemu -->

