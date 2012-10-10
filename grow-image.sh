#!/bin/bash -e

. `dirname "$0"`/common.sh

ruby src/grow_image.rb "$IMGFILE" $@
