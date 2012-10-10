#!/bin/sh
# See /usr/share/doc/initramfs-tools and/or initramfs-tools(8)
#
#  CONFDIR -- usually /etc/initramfs-tools, can be set on mkinitramfs
#     command line.
#
#  DESTDIR -- The staging directory where we are building the image.
#

prereqs()
{
  echo ""
}

case $1 in
# get pre-requisites
prereqs)
  prereqs
  exit 0
  ;;
esac

. /usr/share/initramfs-tools/hook-functions

copy_exec /usr/bin/find bin
copy_exec /bin/grep bin
copy_exec /bin/sed bin

copy_exec /usr/local/sbin/growpart sbin
copy_exec /usr/local/bin/parent-dev bin

if command -v resize2fs >/dev/null 2>&1; then
  copy_exec /sbin/resize2fs sbin
fi

if command -v e2fsck >/dev/null 2>&1; then
  copy_exec /sbin/e2fsck sbin
fi

exit 0

