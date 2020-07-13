#!/bin/bash

# A script to configure a KVM from a cloud image using the libvirt tools
# @author Tasman Mayers
# @date June 2020

# Usage (Run as root)

VM=$1
if [ -z $VM ]; then exit 1; fi
echo "-- This script will PERMENANTLY DESTROY THE INSTANCE $VM --"
echo "--! Press ENTER to proceed or any key to exit !--"
read -sn1 
if [ "$REPLY" != "" ]; then
    echo "-- Aborting VM destroy operation --"
    exit 0
fi
DATA_DIRECTORY="/var/lib/libvirt/images/$VM"
KEY_DIRECTORY="/root/.ssh"
virsh destroy $VM && virsh undefine $VM
rm -r $DATA_DIRECTORY
rm -f "$KEY_DIRECTORY/$VM" && rm -f "$KEY_DIRECTORY/$VM.pub"
echo "-- DONE --"