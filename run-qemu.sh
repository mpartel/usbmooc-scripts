#!/bin/bash -e

. `dirname "$0"`/common.sh

qemu-system-i386 -hda images/current.img -m 512M -net user -net nic
