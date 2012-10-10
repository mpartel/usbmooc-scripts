#!/bin/bash -e

. `dirname "$0"`/common.sh

ROOT="$MOUNTPOINT"

mount_image

make -C src growpart parent-dev
cp -f src/growpart "$ROOT"/usr/local/sbin/growpart
cp -f src/parent-dev "$ROOT"/usr/local/bin/parent-dev

cp -f initrd-growfs/hooks/install-growfs-binaries.sh "$ROOT"/etc/initramfs-tools/hooks/
chmod a+x "$ROOT"/etc/initramfs-tools/hooks/install-growfs-binaries.sh
cp -f initrd-growfs/scripts/init-premount/growfs.sh "$ROOT"/etc/initramfs-tools/scripts/init-premount/growfs.sh
chmod a+x "$ROOT"/etc/initramfs-tools/scripts/init-premount/growfs.sh

unmount_image

echo "Updating initrd"
chrooter/build/linux.uml \
  mem=128M \
  ubda="$IMGFILE" \
  initrd=chrooter/build/initrd.img \
  UPDATE_INITRAMFS
