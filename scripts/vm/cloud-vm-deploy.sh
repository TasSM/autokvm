#!/bin/bash

# A script to configure a KVM from a cloud image using the libvirt tools
# @author Tasman Mayers
# @date June 2020

# REQUIREMENTS
# cloud-init
# libvirt

# VARIABLES
DIRECTORY="/var/lib/libvirt/images"
KEY_DIRECTORY="/root/.ssh"
# TODO: REWRITE AS ARGUMENT
TEMPLATE="templates/centos8-template.yml"
#
DISK_SIZE=
PUBLIC_KEY=
VALIDITY=
INSTALL_IMAGE=$1
MACHINE_NAME=$2
USERNAME=$3
IP_CONFIG=


LOCALE=
IP_ADDRESS=
GATEWAY=
DNS=
PREFIX=

### FUNCTIONS ###

usage() {
    echo "-- USAGE --"
    echo "A script to deploy a VM from a cloud image"
    echo "Tested on RHEL 8"
    echo ""
    echo "$0 [] [] []"
    echo ""
    echo "[-h] This Message"
    echo ""
    echo "--end--"
}

### MAIN ###

# Default disk size to 10G or fail if size invalid
if [ -z $5 ]; then
    DISK_SIZE="10G"
elif [[ "$5" =~ ^[0-9]{1,4}G$ ]]; then
    DISK_SIZE=$5
else
    echo "-- ERROR - Please enter valid disk size variable i.e. \"20G\" --"
    exit 1
fi

# Read IP configuration file
if [ -f $IP_CONFIG ]; then
    source $IP_CONFIG
else
    echo "-- IP configuration file is invalid [Run with -h flag for usage]"
    exit 1
fi

# TODO: ADD SIGINT SIGKILL traps

# TODO: image download process using wget

# Evaluate system parameters
LOCALE=$(timedatectl | grep "Time zone" | sed -e 's/.*zone:\ //' -e 's/\ (.*//')

# Create cloud-init metadata
mkdir -vp "$DIRECTORY/$MACHINE_NAME"
echo "instance-id: $MACHINE_NAME" > "$DIRECTORY/meta-data"
echo "local-hostname: $MACHINE_NAME" >> "$DIRECTORY/meta-data"

# Create cloud-init userdata
ssh-keygen -o -q -t ed25519 -C "Key for VM $MACHINE_NAME" -f "$KEY_DIRECTORY/$MACHINE_NAME" -N ""
PUBLIC_KEY=$(cat $KEY_DIRECTORY/$MACHINE_NAME.pub)
sed -e "s|{{HOSTNAME}}|$MACHINE_NAME|" \
    -e "s|{{USER}}|$USERNAME|"         \
    -e "s|{{PUBKEY}}|$PUBLIC_KEY|"     \
    -e "s|{{LOCALE}}|$LOCALE|" $SOURCE_DIRECTORY/$TEMPLATE \
    -e "s|{{IP_ADDRESS}}|$IP_ADDRESS|" \
    -e "s|{{GATEWAY}}|$GATEWAY|" \
    -e "s|{{PREFIX}}|$PREFIX|" \
    -e "s|{{DNS}}|$DNS|" > "user-data"

# Validate generated config
VALIDITY=$(cloud-init devel schema --config-file user-data)
if [ "${VALIDITY%% *}" == "Valid" ]; then
    echo "-- Valid Configuration Generated --"
else
    echo "-- ERROR - Invalid Config Generated - Check Inputs --"
    exit 1
fi

# Copy the install image
echo "-- Creating installation image --"
cp "$INSTALL_IMAGE" "$DIRECTORY/$MACHINE_NAME.qcow2"

# Create disk image for install
echo "-- Building disk image --"
qemu-img create -f qcow2 -o preallocation=metadata "$DIRECTORY/$MACHINE_NAME.image" $DISK_SIZE
virt-resize --quiet --expand "/dev/sda1" "$DIRECTORY/$MACHINE_NAME.qcow2" "$DIRECTORY/$MACHINE_NAME.image"
mv -f "$DIRECTORY/$MACHINE_NAME.image" "$DIRECTORY/$MACHINE_NAME.qcow2" 

# Create initialization iso
echo "-- Creating cloud-init iso --"
mkisofs -o "$DIRECTORY/$MACHINE_NAME-cidata.iso" -V cidata -J -r "user-data" "meta-data"

# Create the VM
virt-install --import --name $MACHINE_NAME            \
--memory 2048 --vcpus 2 --cpu host                    \
--disk $DIRECTORY/$MACHINE_NAME.qcow2,format=qcow2,device=disk,bus=virtio    \
--disk $DIRECTORY/$MACHINE_NAME-cidata.iso,device=cdrom          \
--network bridge=br0,model=virtio                     \
--os-variant centos8                                  \
--graphics none                                       \
--noautoconsole

# Cleanup
virsh change-media $MACHINE_NAME sda --eject --config
rm "meta-data" "user-data" $DIRECTORY/$MACHINE_NAME-cidata.iso
rm -f "$KEY_DIRECTORY/$MACHINE_NAME.pub"
#cd -

echo "-- SSH Key for $MACHINE_NAME is located in $KEY_DIRECTORY/$MACHINE_NAME --"
exit 0