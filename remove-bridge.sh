#!/bin/bash

# Remove a network bridge and slave connection from a device
# @author Tasman Mayers
# @date July 2020

if [[ "$#" != 1 ]]; then
    echo "Specify network bridge to remove as first argument e.g. br0"
    exit 1
fi

BRIDGE_NAME=$1
BRIDGE_SLAVE="bridge-slave-$BRIDGE_NAME"

nmcli conn down $BRIDGE_NAME
nmcli conn del $BRIDGE_NAME
nmcli conn del $BRIDGE_SLAVE

systemctl restart NetworkManager.service

echo "-- DONE --"
exit 0