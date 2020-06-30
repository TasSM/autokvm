vm=$1
echo "-- This script will PERMENANTLY DESTROY THE INSTANCE $vm --"
echo "--! Press ENTER to proceed or any key to exit !--"
read -sn1 
if [ "$REPLY" != "" ]; then
    echo "-- Aborting VM destroy operation --"
    exit 0
fi
files="/var/lib/libvirt/images/$vm"
virsh destroy $vm
virsh undefine $vm
rm -r $files
echo "-- DONE --"