#!/bin/bash -e

. `dirname "$0"`/common.sh

mount_image

if [ x"$@" = x"" ]; then
    echo "Usage: mount-and.sh <command>"
    exit 1
fi

$@
