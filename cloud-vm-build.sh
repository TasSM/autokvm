#!/bin/bash

# A script to configure a KVM from a cloud image using the libvirt tools
# @author Tasman Mayers
# @date June 2020

# Usage (Run as root):
# $ ./cloud-vm-build.sh [MACHINE-NAME]

# VARIABLES
DIRECTORY="/var/lib/libvirt/boot"
KEY_DIRECTORY="/root/.ssh"
DISK_SIZE="10G"
PUBLIC_KEY=
export MACHINE_NAME=$1
export DOMAIN_NAME=""

mkdir -vp $DIRECTORY/$MACHINE_NAME
echo "instance-id: $MACHINE_NAME" > "$DIRECTORY/$MACHINE_NAME/meta-data"
echo "instance-id: $MACHINE_NAME" >> "$DIRECTORY/$MACHINE_NAME/meta-data"

ssh-keygen -o -q -t ed25519 -C "Key for VM $MACHINE_NAME" -f "$KEY_DIRECTORY/$MACHINE_NAME" -N ""
PUBLIC_KEY=$(cat $KEY_DIRECTORY/$MACHINE_NAME.pub)

