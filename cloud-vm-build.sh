#!/bin/bash

# A script to configure a KVM from a cloud image using the libvirt tools
# @author Tasman Mayers
# @date June 2020

# REQUIREMENTS
# cloud-init
# 

# Usage (Run as root):
# $ ./cloud-vm-build.sh [INSTALL-IMAGE] [MACHINE-NAME] [DOMIAN-NAME] [USERNAME] [LOCALE] [DISK-SIZE]

# VARIABLES
DIRECTORY="/var/lib/libvirt/images"
KEY_DIRECTORY="/root/.ssh"
TEMPLATE="templates/rhel8-template.cfg"
DISK_SIZE=
PUBLIC_KEY=
VALIDITY=
INSTALL_IMAGE=$1
MACHINE_NAME=$2
DOMAIN_NAME=$3
USERNAME=$4
LOCALE=$5
if [ -z $6 ]; then
    DISK_SIZE="10G"
elif [[ "$6" =~ ^[0-9]{1,4}G$ ]]; then
    DISK_SIZE=$6
else
    echo "-- ERROR - Please enter valid disk size variable i.e. \"20G\" --"
    exit 1
fi

# Create Metadata
mkdir -vp "$DIRECTORY/$MACHINE_NAME"
echo "instance-id: $MACHINE_NAME" > "$DIRECTORY/$MACHINE_NAME/meta-data"
echo "local-hostname: $MACHINE_NAME" >> "$DIRECTORY/$MACHINE_NAME/meta-data"

# Create userdata
ssh-keygen -o -q -t ed25519 -C "Key for VM $MACHINE_NAME" -f "$KEY_DIRECTORY/$MACHINE_NAME" -N ""
PUBLIC_KEY=$(cat $KEY_DIRECTORY/$MACHINE_NAME.pub)
sed -e "s|{{HOSTNAME}}|$MACHINE_NAME|" \
    -e "s|{{FQDN}}|$DOMAIN_NAME|"      \
    -e "s|{{USER}}|$USERNAME|"         \
    -e "s|{{PUBKEY}}|$PUBLIC_KEY|"     \
    -e "s|{{LOCALE}}|$LOCALE|" $TEMPLATE > "$DIRECTORY/$MACHINE_NAME/user-data"

# Validate generated config
VALIDITY=$(cloud-init devel schema --config-file "$DIRECTORY/$MACHINE_NAME/user-data")
if [ ${VALIDITY%% *} == "Valid" ]; then
    echo "-- Valid Configuration Generated --"
else
    echo "-- ERROR - Invalid Config Generated - Check Inputs --"
    exit 1
fi

# Copy the install image
echo "-- Creating installation image --"
cp "$INSTALL_IMAGE" "$DIRECTORY/$MACHINE_NAME/$MACHINE_NAME.qcow2"

# Create disk image for install
echo "-- Building disk image --"
qemu-img create -f qcow2 -o preallocation=metadata "$DIRECTORY/$MACHINE_NAME/MACHINE_NAME.image" $DISK_SIZE
virt-resize --quiet --expand "/dev/sda1" "$DIRECTORY/$MACHINE_NAME/$MACHINE_NAME.qcow2" "$DIRECTORY/$MACHINE_NAME/$MACHINE_NAME.image.qcow2"
mv -f "$DIRECTORY/$MACHINE_NAME/$MACHINE_NAME.image.qcow2" "$DIRECTORY/$MACHINE_NAME/$MACHINE_NAME.qcow2" 
