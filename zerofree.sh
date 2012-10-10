#!/bin/sh -e

. `dirname "$0"`/common.sh

mount_image
sleep 1
umount mnt # We actually just want the loopback file
rmdir mnt # Tell common.sh to not try to umount

fsck -f -p "$LOOPBACK_FILE"

echo "Running zerofree..."
zerofree -v "$LOOPBACK_FILE"

fsck -f -p "$LOOPBACK_FILE"
