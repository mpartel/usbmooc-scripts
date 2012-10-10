#!/bin/sh -e

. `dirname "$0"`/common.sh


if [ -z "$RSYNC_DEST" ]; then
    echo "RSYNC_DEST is not set. Set it in settings.sh or in the env."
fi

rsync -avv --chmod=a+rX --progress --exclude=current.img --exclude latest.img.gz images/ $RSYNC_DEST
rsync -avv --chmod=a+rX images/latest.img.gz $RSYNC_DEST/
