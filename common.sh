#!/bin/sh -e
# Sourced by scripts. Override in settings.sh if you want.

cd `dirname "$0"`
IMGFILE=images/current.img
MOUNTPOINT=mnt

if [ -e settings.sh ]; then
    . ./settings.sh
fi

if [ ! -e $IMGFILE ]; then
    echo "$IMGFILE missing"
    exit 1
fi


mkdir -p mnt

mount_image() {
    if [ `whoami` != 'root' ]; then
        echo "This needs to be executed as root."
        exit 1
    fi

    LOOPBACK_FILE=`ruby src/losetup_boot_partition.rb "$IMGFILE"`
    echo "Mounting image."
    if mount "$LOOPBACK_FILE" "$MOUNTPOINT"; then
        trap unmount_image EXIT TERM
    else
        echo "Failed to mount the image."
        losetup -d "$LOOPBACK_FILE"
        exit 1
    fi
}

unmount_image() {
    echo "Unmounting image."
    sleep 1
    [ -d "$MOUNTPOINT" ] && umount "$MOUNTPOINT"
    losetup -d "$LOOPBACK_FILE"
}
