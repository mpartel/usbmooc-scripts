#!/bin/sh

prereqs()
{
  echo "udev"
}

case $1 in
prereqs)
  prereqs
  exit 0
  ;;
esac

. /scripts/functions

# Root device detection yoinked from /usr/share/initramfs-tools/scripts/local-premount/fixrtc
ROOTDEV=""

for x in $(cat /proc/cmdline); do
        case ${x} in
        root=*)
                value=${x#*=}

                # Find the device node path depending on the form of root= :
                case ${value} in
                UUID=*)
                        ROOTDEV=/dev/disk/by-uuid/${value#UUID=}
                        ;;
                LABEL=*)
                        ROOTDEV=/dev/disk/by-label/${value#LABEL=}
                        ;;
                *)
                        ROOTDEV=${value}
                        ;;
                esac
        ;;
        esac
done


for i in `seq 1 40`; do
    if [ ! -e "$ROOTDEV" ]; then
        echo "Waiting for $ROOTDEV to appear..."
        sleep 1
    fi
done

if [ ! -e "$ROOTDEV" ]; then
    echo "Error: root device $ROOTDEV did not appear"
    exit 1
fi

DISK=`parent-dev "$ROOTDEV"`
if [ -n "$DISK" ]; then
    if growpart --check "$DISK"; then
        echo "Resizing root partition to use available free space."
        echo "This is done only once."
        echo ""
        echo "Root is $ROOTDEV"
        echo "Disk is $DISK"

        e2fsck -f -p "$ROOTDEV"

        growpart "$DISK"
        sleep 2 # growpart just reread the partition table. Wait for rootdev to reappear.

        resize2fs "$ROOTDEV"
        e2fsck -f -p "$ROOTDEV"
    fi
else
    echo "Disk for $ROOTDEV not found :("
fi

exit 0

