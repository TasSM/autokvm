#!/bin/bash

# A script to configure dependencies for your autokvm
# @author Tasman Mayers
# @date July 2020

CONFIG_DIR="/etc/autokvm.cfg.d"

### MAIN ###

echo "-----------------------------------------------------"
echo "-- Configuring autokvm and installing dependencies --"
echo "-----------------------------------------------------"

# Validate user
if [[ "$(id -u)" != 0 ]]; then
    echo "-- ERROR: This script must be run as root user --"
    exit 1
fi

# Validate virtualization technology
if [[ -z $(lscpu | grep 'VT-x\|AMD-V') ]]; then
    echo "-- ERROR: Virtualization is not enabled - review BIOS settings --"
    exit 1
else 
    echo "-- Host Virtualization Technology Validated --"
fi

# Install dependencies
echo "-- Installing Dependencies --"
dnf module install virt -y
dnf install virt-install virt-viewer libguestfs-tools cloud-init -y

# Start services
echo "-- Starting Services --"
systemctl enable libvirtd.service
systemctl start libvirtd.service

# Validate installation
if [[ -z $(lsmod | grep -i kvm) ]]; then
    echo "-- ERROR: KVM installation appears invalid"
    exit 1
fi

# Install autokvm config files
echo "-- Installing configration in $CONFIG_DIR --"
mkdir -p "$CONFIG_DIR/example"
cp -r "templates/" $CONFIG_DIR
cp "config/operating-systems.conf" $CONFIG_DIR
cp "config/network-config-sample.conf" "$CONFIG_DIR/example"
cp "config/vm-config-sample.conf" "$CONFIG_DIR/example"

echo "-- DONE --"
exit 0
