#!/bin/sh -e

. `dirname "$0"`/common.sh

if [ -z "$1" ]; then
    echo "Error: missing argument"
    exit 1
fi

src/resize_disk.rb "$IMGFILE" "$1"

