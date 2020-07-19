#!/bin/bash

# A script to configure a KVM from a cloud image using the libvirt tools
# @author Tasman Mayers
# @date June 2020

usage() {
    echo "-- USAGE --"
    echo "A script to teardown and delete a VM"
    echo "Tested on RHEL 8"
    echo ""
    echo "$0 [VM-NAME] [-f]"
    echo ""
    echo "[-f --force] Force deletion without user input"
    echo "[-h --help] This Message"
    echo ""
    echo "-- END --"
}

if [[ -z $1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

VM=$1
FLAG=$2

if [[ "$FLAG" != "--force" && "$FLAG" != "-f" ]]; then
    echo "-- This script will PERMENANTLY DESTROY THE INSTANCE $VM --"
    echo "--! Press ENTER to proceed or any key to exit !--"
    read -sn1 
    if [ "$REPLY" != "" ]; then
        echo "-- Aborting VM destroy operation --"
        exit 0
    fi
fi

DATA_DIRECTORY="/var/lib/libvirt/images/$VM"
KEY_DIRECTORY="/root/.ssh"
virsh destroy $VM && virsh undefine $VM
rm -r $DATA_DIRECTORY
rm -f "$KEY_DIRECTORY/$VM" && rm -f "$KEY_DIRECTORY/$VM.pub"
echo "-- DONE --"
exit 0