#!/bin/bash

source "common.sh"
source "$PROJECT_DIR/vms/vbmc-funcs.sh"

for i in $(sudo virsh list --all | grep $CLUSTER_NAME | awk '{print $2}'); do
    delete_vbmc "$i"
    sudo virsh destroy $i > /dev/null 2>&1
    sudo virsh vol-delete $i.qcow2 --pool=$LIBVIRT_STORAGE_POOL
    sudo virsh undefine $i
done