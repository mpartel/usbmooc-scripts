#!/bin/bash -e

. `dirname "$0"`/common.sh

ruby src/shrink_image.rb "$IMGFILE"
