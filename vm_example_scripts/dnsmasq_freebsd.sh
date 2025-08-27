#!/bin/sh -

#VARIABLES

# === Security and initialization ===
IFS=' '   # Reset IFS to prevent parsing attacks
# === Default values ===
ENABLE_DNS="yes"
ENABLE_DHCP="no"
ENABLE_PXE="no"
DNSMASQ_DCONF_DIR="/usr/local/etc/dnsmasq.conf.d"
DNSMASQ_CONFIG_FILE="/usr/local/etc/dnsmasq.conf"
LOCAL_NETWORK="192.168.1"
LOCAL_NETWORK_GATEWAY="${LOCAL_NETWORK}.1"
LOCAL_NETWORK_RANGE="${LOCAL_NETWORK}.0/24"
LOCAL_NETWORK_DHCP_FIRST_IP="50"
LOCAL_NETWORK_DHCP_LAST_IP="254"
LOCAL_NETWORK_NETMASK="255.255.255.0"
LOCAL_NETWORK_DHCP_LEASE="12h"
LOCAL_DOMAIN="pozal.lan"

#FUNCTIONS
# === Function: print header ===
print_header() 
{
    printf '%s\n' "================================"
    printf '%s\n' "  Dnsmasq Service Enabler"
    printf '%s\n' "================================"
}

# === Function: ask yes/no ===
ask_yes_no() 
{
    # Usage: ask_yes_no "Question?" default(y/n)
    prompt="$1"
    default="$2"

    while true; do
        printf '%s ' "${prompt} (y/n) [${default}]: "
        read -r response
        case "${response:-${default}}" in
            [Yy]|[Yy][Ss])
                echo "yes"
                return 0
                ;;
            [Nn]|[Nn][Oo])
                echo "no"
                return 0
                ;;
            *)
                printf '%s\n' "Please answer yes or no."
                ;;
        esac
    done
}

change_config()
{
    REPLACEMENTS_FILE=$1
    if [ ! -f "${DNSMASQ_CONFIG_FILE}" ]; then
        echo "Error: Config file '${DNSMASQ_CONFIG_FILE}' not found." >&2
        exit 1
    fi

    if [ ! -r "${REPLACEMENTS_FILE}" ]; then
        echo "Error: Replacements file '${REPLACEMENTS_FILE}' not found or not readable." >&2
        exit 1
    fi

    cp "${DNSMASQ_CONFIG_FILE}" "${DNSMASQ_CONFIG_FILE}.bak" || {
        echo "Error: Failed to create backup." >&2
        exit 1
    }

    while IFS='@@@' read -r old new || [ -n "${old}" ]; do
        # Saltar líneas vacías o comentarios
        case "${old}" in
            ""|\#*) continue ;;
        esac

        # Aplicar sustitución con sed (usando | como delimitador)
        if ! sed -i '' "s|${old}|${new}|g" "${DNSMASQ_CONFIG_FILE}"; then
            echo "Error: Failed to replace '${old}' with '${new}'." >&2
            exit 1
        fi

        echo "Replaced: '${old}' -> '${new}'"
    done < "${REPLACEMENTS_FILE}"

    echo "All replacements applied successfully."
}

change_dnsmasq_config()
{  
    if [ "${ENABLE_DNS}" = "yes" ]; then
        enable_dns
    fi

    if [ "${ENABLE_DHCP}" = "yes" ]; then
        enable_dhcp
    fi

    if [ "${ENABLE_PXE}" = "yes" ]; then
        enable_pxe
    fi
}


enable_dns()
{
    change_config vm_template_files/dnsmasq_conf_dns
    echo "dhcp-option=6,\"${JAIL_IP_ADDRESS},1.1.1.1\"" >> "${DNSMASQ_CONFIG_FILE}"
    DNSMASQ_LISTS="vm_template_files/dnsmasq_lists.txt"
    while IFS='@@@' read -r url file|| [ -n "${url}" ]; do
        # Saltar líneas vacías o comentarios
        case "${url}" in
            ""|\#*) continue ;;
        esac
        curl -L -o "${file}" \
        "${{url}}" 
        
    done < "${DNSMASQ_LISTS}"

}

enable_dhcp()
{
    change_config vm_template_files/dnsmasq_conf_dhcp
}

enable_pxe()
{
    #change_config vm_template_files/dnsmasq_conf_pxe
    echo "dhcp-option=66,\"0.0.0.0\"" >> "${DNSMASQ_CONFIG_FILE}"
}



#MAIN
#Install package
pkg install dnsmasq
#Apply config
# === Main ===
print_header
# Ask for each service
ENABLE_DHCP="$(ask_yes_no "Enable DHCP server" "n")"
ENABLE_PXE="$(ask_yes_no "Enable PXE boot server" "n")"
change_dnsmasq_config
sysrc dnsmasq_enable="YES"
sysrc dnsmasq_conf="/usr/local/etc/dnsmasq.conf"