# kvm-cloudimage
Use cloud images on baremetal using libvirt/kvm
# Pre-requisites
- openssh
- mkpass (whois)
## Creating VMs
### Usage
```shell
usage: ./vm_create.sh options

Quickly create guest VMs using cloud image files and cloud-init.

OPTIONS:
   -h      Show this message
   -n      Host name (required)
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

FreeBSD 14 is still in process

### Examples
```shell
./vm_connect.sh -ntestMachine
```
A VM will ve created with default values

```shell
./vm_connect.sh -ntestMachine -r4098 -c4 -s100
```
A VM will be created with 4098 MB of RAM, 4 vCPUs and 100Gb of storage

## List VMs
```shell
./vm_list.sh 
 Id   Nombre       Estado
-------------------------------
 7    debianTest   ejecutando
 8    ubuntuTest   ejecutando
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

- FreeBSD support is in progress
- Only NAT network are allowed by the moment, bridge support is in progress
