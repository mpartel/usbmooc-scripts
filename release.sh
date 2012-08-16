#!/bin/sh -e

. `dirname "$0"`/common.sh

if [ -z "$1" ]; then
    echo "Error: missing argument"
    exit 1
fi

TGTFILE="images/$1.img.gz"

if [ -e "$TGTFILE" ]; then
    echo "Error: $TGTFILE already exists"
    exit 1
fi

cat "$IMGFILE" | gzip > "$TGTFILE"
cd images
rm -f latest.img.gz
ln -s $1.img.gz latest.img.gz
sync
