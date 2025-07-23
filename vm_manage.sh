#!/bin/env bash

source env_scripts/common.sh
source env_scripts/functions.sh
# Default values for VM creation parameters
VM_MEM_SIZE=1024
VM_VCPUS=1
VM_DISK_SIZE=10

# Function to display usage message
usage() {
    echo "Usage: $0 create -n NAME [-b BRIDGE] [-r RAM] [-c VCPUS] [-s DISK] [-v]"
    echo "       $0 delete -n NAME"
    echo "       $0 info -n NAME"
    echo "       $0 connect -n NAME"
    echo "       $0 list"
    echo ""
    echo "Actions:"
    echo "  create     Create a new virtual machine"
    echo "  delete     Delete a virtual machine"
    echo "  list       List all defined virtual machines"
    echo "  info       Show information about a virtual machine"
    echo "  connect    Connect to the console of a virtual machine"
    echo ""
    echo "Options for 'create':"
    echo "  -h         Show this help message"
    echo "  -n NAME    Host name (required)"
    echo "  -b BRIDGE  Bridge interface name"
    echo "  -r RAM     RAM in MB (default: ${VM_MEM_SIZE})"
    echo "  -c VCPUS   Number of VCPUs (default: ${VM_VCPUS})"
    echo "  -s DISK    Disk size in GB (default: ${VM_DISK_SIZE})"
    echo "  -v         Verbose mode"
    exit 1
}

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    usage
fi

ACTION="$1"
shift

case "${ACTION}" in
    create)
        # Parse options for create command
        VERBOSE=false
        NAME_SET=false

        while getopts ":hn:b:r:c:s:v" opt; do
            case "${opt}" in
                h)
                    usage
                    ;;
                n)
                    VM_HOSTNAME="${OPTARG}"
                    NAME_SET=true
                    ;;
                b)
                    BRIDGE_INTERFACE="${OPTARG}"
                    ;;
                r)
                    VM_MEM_SIZE="${OPTARG}"
                    ;;
                c)
                    VM_VCPUS="${OPTARG}"
                    ;;
                s)
                    VM_DISK_SIZE="${OPTARG}"
                    ;;
                v)
                    VERBOSE=true
                    ;;
                \?)
                    echo "Invalid option: -${OPTARG}" >&2
                    usage
                    ;;
                :)
                    echo "Option -${OPTARG} requires an argument." >&2
                    usage
                    ;;
            esac
        done

        # Check that required parameter (-n) was provided
        if ! ${NAME_SET}; then
            echo "Error: The -n option is required for create action." >&2
            usage
        fi
        source env_scripts/common.sh
        #Check network type
        vm_net_set_bridge_mode
        #Check host os for guest debian type
        check_host_os
        #Read os_options.json and generate guests menu
        #Select guest
        show_vm_menu
        #Set guest type based on check_host_os
        vm_set_guest_type
        #Download cloud image
        vm_download_base_image
        #Compare hashes
        compare_checksum
        #Create guest image
        vm_create_guest_image
        #Generate ssh key
        vm_generate_ssh_hey
        #Generate meta-data file for VM
        vm_gen_meta_data
        #Generate user-data file for VM
        vm_gen_user_data
        #Install VM
        vm_guest_install
        ;;

    delete|info|connect)
        # These actions require a NAME directly as first argument after ACTION
        if [ $# -ne 1 ]; then
            echo "Error: ${ACTION} requires a VM name as argument." >&2
            usage
        fi
        VM_HOSTNAME="$1"
        source env_scripts/common.sh
        if [[ "${ACTION}" == 'delete' ]]; then
            vm_delete ${VM_HOSTNAME}
	    elif [[ "${ACTION}" == 'info' ]]; then
            vm_net_get_ip ${VM_HOSTNAME}
	    elif [[ "${ACTION}" == 'connect' ]]; then
            vm_connect ${VM_HOSTNAME}
	    fi
        ;;

    list)
        vm_list
        ;;

    *)
        echo "Unknown action: ${ACTION}" >&2
        usage
        ;;
esac
exit 0