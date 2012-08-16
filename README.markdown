Maintenance scripts and documentation for a live USB image
meant for use with [http://mooc.fi/](http://mooc.fi/).

The image files may be downloaded [here](http://new.testmycode.net/usbmooc/).


## Basic usage ##

The image is based on Linux Mint 13 and lives in a raw disk file, including the partition table.
The system is assumed to be installed on a single partition that is marked bootable.

Edit the image under QEMU with a command like

    qemu-system-i386 -hda images/current.img -m 512M -net user -net nic

See [here](http://qemu.weilnetz.de/qemu-doc.html#sec_005finvocation) for more options


## clean-image.sh ##

Mounts the image and

- removes bash history
- removes `.ssh/known_hosts`
- clears recently opened documents
- clears Firefox cache, cookies, history and downloads (but not settings)
- clears `/tmp` and `/var/tmp`
- clears apt's package cache
- removes the TMC plugin's settings

Must be run as root.
Requires ruby, sqlite3 and parted.


## zerofree.sh ##

Runs zerofree on the image to increase its compressability.


## release.sh ##

Usage:

    release.sh version-number

Compresses `images/current.img` to `images/version-number.img.gz` and sets `images/latest.img.gz` to point to it.


## rsync.sh ##

Set RSYNC_DEST to something like `user@server:/path/to/webdir/` in `settings.sh` or on the shell.
Then call this. It will sync everything under `images/` except for `current.img`.

The full release sequence is:

- clean-image.sh
- zerofree.sh
- release.sh
- test the image in a VM
- rsync.sh

## TODO ##

A script to resize the image, with its partitions, to fit on a smaller or larger device.
