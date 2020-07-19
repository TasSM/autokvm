#!/bin/bash

# A script to configure a KVM from a cloud image using the libvirt tools
# @author Tasman Mayers
# @date June 2020

# SCRIPT VARS
MACHINE_NAME=$1
OPERATING_SYSTEM=$2
MACHINE_CONFIG_FILE=$3
IP_CONFIG_FILE=$4
TARGET_URL=
INSTALL_IMAGE=
METADATA_FILE=
USERDATA_FILE=

# PATHS
LIBVIRT_BOOT_DIR="/var/lib/libvirt/boot"
LIBVIRT_IMAGE_DIR="/var/lib/libvirt/images"
AUTOKVM_CONFIG_DIR="/etc/autokvm.cfg.d"
TEMPLATE_DIR="$AUTOKVM_CONFIG_DIR/templates"
OS_FILE="$AUTOKVM_CONFIG_DIR/operating-systems.conf"

# MACHINE PARAMS
DISK_SIZE=
PUBLIC_KEY=
VALIDITY=
SSH_KEY_DIRECTORY=
USERNAME=
PRESERVE_PUBKEY=
TEMPLATE=
BRIDGE_INTERFACE=
RAM=
VCPUS=
GRAPHICS=

# NETWORK PARAMS
LOCALE=
IP_ADDRESS=
GATEWAY=
DNS=
NETMASK=

### FUNCTIONS ###

clup() {
    echo "-- KILLED: Running Cleanup Job --"
    virsh destroy $MACHINE_NAME && virsh undefine $MACHINE_NAME
    rm -rf "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME"
    rm -f "$SSH_KEY_DIRECTORY/$MACHINE_NAME" && rm -f "$SSH_KEY_DIRECTORY/$MACHINE_NAME.pub"
}

usage() {
    echo "-- USAGE --"
    echo "A script to deploy a VM from a cloud image"
    echo "Tested on RHEL 8"
    echo ""
    echo "$0 [hostname] [OS] [vm-config] [network-config]"
    echo ""
    echo "For supported OS see config/operating-systems.conf"
    echo ""
    echo "[-h] This Message"
    echo ""
    echo "-- END --"
}

### MAIN ###

# Validate Parameters
if [[ "$#" != 4 ]]; then
    usage
    exit 1
fi

# Read VM and IP configuration file
if [ ! -f $MACHINE_CONFIG_FILE ]; then
    echo "-- VM configuration file is invalid [Run with -h flag for usage]"
    exit 1
elif [ ! -f $IP_CONFIG_FILE ]; then
    echo "-- IP configuration file is invalid [Run with -h flag for usage]"
    exit 1
else
    echo "-- Reading Machine and Network Configuration --"
    source $MACHINE_CONFIG_FILE
    source $IP_CONFIG_FILE
fi

# Validate disk size
if [[ ! "$DISK_SIZE" =~ ^[0-9]{1,4}G$ ]]; then
    echo "-- ERROR - Disk size $DISK_SIZE is invalid"
    exit 1
fi

# Validate OS parameter
TARGET_URL=$(awk -F= /$OPERATING_SYSTEM-location/'{print $2}' $OS_FILE)
if [ -z "$TARGET_URL" ]; then
    echo "-- ERROR: Enter a supported operating system, see config/operating-systems.conf"
    exit 1
fi

INSTALL_IMAGE=${TARGET_URL##*/}
TEMPLATE="$TEMPLATE_DIR/$OPERATING_SYSTEM-template.yml"
echo "-- Install Image: ${INSTALL_IMAGE} --"
echo "-- Template: $TEMPLATE --"

# Download machine image if not present
if [ -f "$LIBVIRT_BOOT_DIR/$INSTALL_IMAGE" ]; then 
    echo "-- Image for $OPERATING_SYSTEM [$INSTALL_IMAGE] is already downloaded -- "
else
    echo "-- Downloading $OPERATING_SYSTEM image $INSTALL_IMAGE -- "
    wget -v $TARGET_URL -P "$LIBVIRT_BOOT_DIR/"
fi

# Evaluate system parameters
LOCALE=$(timedatectl | grep "Time zone" | sed -e 's/.*zone:\ //' -e 's/\ (.*//')

# Trap signals
trap clup SIGINT SIGKILL

# Create cloud-init metadata with network config
mkdir -vp "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME"
LIBVIRT_IMAGE_DIR="$LIBVIRT_IMAGE_DIR/$MACHINE_NAME"
METADATA_FILE="$LIBVIRT_IMAGE_DIR/meta-data"
USERDATA_FILE="$LIBVIRT_IMAGE_DIR/user-data"
NETWORKDATA_FILE="$LIBVIRT_IMAGE_DIR/network-config"
echo "instance-id: $MACHINE_NAME" > $METADATA_FILE
echo "hostname: $MACHINE_NAME" >> $METADATA_FILE

# Copy network config
echo "-- Writing network configuration --"
sed -e "s|{{IP_ADDRESS}}|$IP_ADDRESS|" \
    -e "s|{{PREFIX}}|$PREFIX|"         \
    -e "s|{{GATEWAY}}|$GATEWAY|"       \
    -e "s|{{DNS1}}|$DNS1|"             \
    -e "s|{{DNS2}}|$DNS2|" "$TEMPLATE_DIR/network-template.yml" > $NETWORKDATA_FILE
       

# Create cloud-init userdata
ssh-keygen -o -q -t ed25519 -C "Key for VM $MACHINE_NAME" -f "$SSH_KEY_DIRECTORY/$MACHINE_NAME" -N ""
PUBLIC_KEY=$(cat $SSH_KEY_DIRECTORY/$MACHINE_NAME.pub)
sed -e "s|{{HOSTNAME}}|$MACHINE_NAME|" \
    -e "s|{{USER}}|$USERNAME|"         \
    -e "s|{{PUBKEY}}|$PUBLIC_KEY|"     \
    -e "s|{{LOCALE}}|$LOCALE|" $TEMPLATE > $USERDATA_FILE

# Validate generated config
VALIDITY=$(cloud-init devel schema --config-file $USERDATA_FILE)
if [ "${VALIDITY%% *}" == "Valid" ]; then
    echo "-- Valid Configuration Generated --"
else
    echo "-- ERROR - Invalid Config Generated - Check Inputs --"
    exit 1
fi

# Copy the install image
echo "-- Creating installation image --"
cp "$LIBVIRT_BOOT_DIR/$INSTALL_IMAGE" "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME.qcow2"

# Create disk image for install
echo "-- Building disk image --"
qemu-img create -f qcow2 -o preallocation=metadata "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME.image" $DISK_SIZE
virt-resize --quiet --expand "/dev/sda1" "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME.qcow2" "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME.image"
mv -f "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME.image" "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME.qcow2" 

# Create initialization iso
echo "-- Creating cloud-init iso --"
mkisofs -o "$LIBVIRT_IMAGE_DIR/$MACHINE_NAME-cidata.iso" -V cidata -J -r $USERDATA_FILE $METADATA_FILE $NETWORKDATA_FILE

# Create the VM
virt-install --import --name $MACHINE_NAME                                           \
--memory $RAM --vcpus $VCPUS --cpu host                                              \
--disk $LIBVIRT_IMAGE_DIR/$MACHINE_NAME.qcow2,format=qcow2,device=disk,bus=virtio    \
--disk $LIBVIRT_IMAGE_DIR/$MACHINE_NAME-cidata.iso,device=cdrom                      \
--network bridge=$BRIDGE_INTERFACE,model=virtio                                      \
--os-variant $OPERATING_SYSTEM                                                       \
--graphics $GRAPHICS                                                                 \
--noautoconsole

# Cleanup
virsh change-media $MACHINE_NAME sda --eject --config
rm -f $USERDATA_FILE $METADATA_FILE $NETWORKDATA_FILE $LIBVIRT_IMAGE_DIR/$MACHINE_NAME-cidata.iso
if [ "$PRESERVE_PUBKEY" != "true" ]; then 
    rm -f "$SSH_KEY_DIRECTORY/$MACHINE_NAME.pub"
fi

echo "-- SSH Key for $MACHINE_NAME is located in $SSH_KEY_DIRECTORY/$MACHINE_NAME --"
echo "-- Connect to host with: ssh $USERNAME@$IP_ADDRESS -i $SSH_KEY_DIRECTORY/$MACHINE_NAME -- "
echo "-- DONE --"
exit 0