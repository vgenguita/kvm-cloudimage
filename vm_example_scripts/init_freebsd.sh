#!/bin/csh

# Variables
set IP = "$1"
set HOSTNAME = "$2"
set IP_RANGE = `echo "$IP" | sed 's/\.[0-9]*$//'`
set IP_GATEWAY = "1"
set IP_NETMASK = "255.255.255.0"

# Jail related config (assuming you need these)
sysrc jail_enabled="YES"
sysrc cloned_interfaces="lagg0"

# Set hostname
sysrc hostname="$HOSTNAME.local"

# Set IP
sysrc ifconfig_em0="inet $IP netmask $IP_NETMASK broadcast $IP_RANGE.255"
sysrc defaultrouter="$IP_RANGE.$IP_GATEWAY"

# Set DNS
cat > /etc/resolv.conf << EOF
nameserver 208.67.222.222
nameserver 208.67.220.220
EOF

# Restart network
service netif restart
service routing restart
