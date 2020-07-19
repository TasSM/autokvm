#!/bin/bash

# Remove a network bridge and slave connection from a device
# @author Tasman Mayers
# @date July 2020

### FUNCTIONS ###

usage() {
    echo "-- USAGE --"
    echo "A script to disconnect and remove a network bridge interface using nmcli"
    echo "Tested on RHEL 8"
    echo ""
    echo "$0 [BRIDGE_NAME]"
    echo ""
    echo "[-h --help] This Message"
    echo ""
    echo "-- END --"
}

### MAIN ###

if [[ "$#" != 1 || "$1" == "-h" || "$1" == "--help"]]; then
## Installation

nmcli conn down $BRIDGE_NAME
nmcli conn del $BRIDGE_NAME
nmcli conn del $BRIDGE_SLAVE

systemctl restart NetworkManager.service

echo "-- DONE --"
exit 0