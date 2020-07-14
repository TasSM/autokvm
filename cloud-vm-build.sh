#!/bin/bash

# A script to configure a KVM from a cloud image using the libvirt tools
# @author Tasman Mayers
# @date June 2020

# REQUIREMENTS
# cloud-init
# libvirt

# Usage (Run as root):
# $ cloud-vm-build.sh [INSTALL-IMAGE] [MACHINE-NAME] [USERNAME] [LOCALE] [DISK-SIZE]

# VARIABLES
DIRECTORY="/var/lib/libvirt/images"
KEY_DIRECTORY="/root/.ssh"
TEMPLATE="templates/centos8-template.yml"
SOURCE_DIRECTORY="/home/admin/repos/autokvm"
DISK_SIZE=
PUBLIC_KEY=
VALIDITY=
INSTALL_IMAGE=$1
MACHINE_NAME=$2
USERNAME=$3
LOCALE=$4
if [ -z $5 ]; then
    DISK_SIZE="10G"
elif [[ "$5" =~ ^[0-9]{1,4}G$ ]]; then
    DISK_SIZE=$5
else
    echo "-- ERROR - Please enter valid disk size variable i.e. \"20G\" --"
    exit 1
fi

# Create Metadata
mkdir -vp "$DIRECTORY/$MACHINE_NAME"
cd "$DIRECTORY/$MACHINE_NAME"
echo "instance-id: $MACHINE_NAME" > "meta-data"
echo "local-hostname: $MACHINE_NAME" >> "meta-data"

# Create userdata
ssh-keygen -o -q -t ed25519 -C "Key for VM $MACHINE_NAME" -f "$KEY_DIRECTORY/$MACHINE_NAME" -N ""
PUBLIC_KEY=$(cat $KEY_DIRECTORY/$MACHINE_NAME.pub)
sed -e "s|{{HOSTNAME}}|$MACHINE_NAME|" \
    -e "s|{{USER}}|$USERNAME|"         \
    -e "s|{{PUBKEY}}|$PUBLIC_KEY|"     \
    -e "s|{{LOCALE}}|$LOCALE|" $SOURCE_DIRECTORY/$TEMPLATE > "user-data"

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
cp "$INSTALL_IMAGE" "$MACHINE_NAME.qcow2"

# Create disk image for install
echo "-- Building disk image --"
qemu-img create -f qcow2 -o preallocation=metadata "$MACHINE_NAME.image" $DISK_SIZE
virt-resize --quiet --expand "/dev/sda1" "$MACHINE_NAME.qcow2" "$MACHINE_NAME.image"
mv -f "$MACHINE_NAME.image" "$MACHINE_NAME.qcow2" 
# Create initialization iso
echo "-- Creating cloud-init iso --"
mkisofs -o "$MACHINE_NAME-cidata.iso" -V cidata -J -r "user-data" "meta-data"

# Create the VM
virt-install --import --name $MACHINE_NAME            \
--memory 2048 --vcpus 2 --cpu host                    \
--disk $MACHINE_NAME.qcow2,format=qcow2,device=disk,bus=virtio    \
--disk $MACHINE_NAME-cidata.iso,device=cdrom          \
--network bridge=br0,model=virtio                     \
--os-variant centos8                                  \
--graphics none                                       \
--noautoconsole

# Cleanup
virsh change-media $MACHINE_NAME sda --eject --config
rm "meta-data" "user-data" $MACHINE_NAME-cidata.iso
rm -f "$KEY_DIRECTORY/$MACHINE_NAME.pub"
cd -

echo "-- SSH Key for $MACHINE_NAME is located in $KEY_DIRECTORY/$MACHINE_NAME --"
exit 0