#!/bin/bash

# Create a network bridge with specified parameters using nmcli
# @author Tasman Mayers
# @date July 2020

CONNECTION=$1
BRIDGE_NAME=$2
IP_CONFIG=$3
BRIDGE_SLAVE="bridge-slave-$BRIDGE_NAME"

# Config file vars
IP_ADDRESS=
GATEWAY=
DNS1=
DNS2=
PREFIX=

### FUNCTIONS ###

usage() {
    echo "-- USAGE --"
    echo "A script to create a network bridge interface using nmcli"
    echo "Tested on RHEL 8"
    echo ""
    echo "$0 [CONNECTION_NAME] [BRIDGE_NAME] [IP_CONFIG_FILE_PATH]"
    echo "EXAMPLE: $0 eth0 br0 static-ip.conf"
    echo ""
    echo "[-h --help] This Message"
    echo ""
    echo "-- END --"
}

escape() {
    nmcli conn down $BRIDGE_NAME
    nmcli conn del $BRIDGE_NAME
    nmcli conn del $BRIDGE_SLAVE
    nmcli conn up Wired\ connection\ 1
    exit 0
}

### MAIN ###

# Display usage message
if [[ "$1" == "-h" || "$1" == "--help" || -z $1 || "$#" != 3 ]]; then
    usage
    exit 1
fi

# Read configration file
if [ -f $IP_CONFIG ]; then
    source $IP_CONFIG
else
    echo "-- IP configuration file is invalid [Run with -h flag for usage]"
    exit 1
fi

# Create bridge
nmcli conn add type bridge con-name $BRIDGE_NAME ifname $BRIDGE_NAME

trap escape SIGTERM SIGINT

# Configure the bridge with static IP configuration
nmcli conn modify $BRIDGE_NAME ipv4.addresses "$IP_ADDRESS/$PREFIX"
nmcli conn modify $BRIDGE_NAME ipv4.gateway $GATEWAY
nmcli conn modify $BRIDGE_NAME ipv4.dns "$DNS1 $DNS2"
nmcli conn modify $BRIDGE_NAME ipv4.method "manual"

# Add interface as bridge slave
nmcli conn add type ethernet slave-type bridge con-name $BRIDGE_SLAVE ifname $CONNECTION master $BRIDGE_NAME

systemctl restart NetworkManager.service
nmcli conn up $BRIDGE_NAME
nmcli conn down Wired\ connection\ 1

echo "-- DONE --"
exit 0