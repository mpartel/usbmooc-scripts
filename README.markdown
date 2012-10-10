Maintenance scripts and documentation for a live USB image
meant for use with [http://mooc.fi/](http://mooc.fi/).

The image files may be downloaded [here](http://testmycode.net/usbmooc/).


## Building the tools ##

    make -C src
    make -C chrooter

If you're on a 64-bit system, your compiler must be able to generate i386 executables.
You may need to install `gcc-multilib` on Debian-derivatives.


## Usage ##

The image is based on 32-bit Linux Mint 13 and lives in a raw disk file, including the partition table.
The system is assumed to be installed on a single ext2/3 partition that is marked bootable.

Edit the image under QEMU with a command like

    qemu-system-i386 -hda images/current.img -m 512M -net user -net nic

See [here](http://qemu.weilnetz.de/qemu-doc.html#sec_005finvocation) for more options

Installing and configuring the `swapspace` package is recommended, since the scripts currently don't
support swap partitions.


## clean-image.sh ##

Mounts the image and

- removes bash history
- removes `.ssh/known_hosts`
- clears recently opened documents
- clears Firefox cache, cookies, history and downloads (but not settings)
- clears .cache
- clears `/tmp` and `/var/tmp`
- clears apt's package cache
- removes the TMC plugin's settings

Must be run as root since it needs to mount the image.
Requires ruby, sqlite3 and parted 3.x.


## zerofree.sh ##

Runs zerofree on the image to increase its compressability.


## release.sh ##

Usage:

    release.sh version-number

Compresses `images/current.img` to `images/version-number.img.gz` and sets `images/latest.img.gz` to point to it.


## rsync.sh ##

Set RSYNC_DEST to something like `user@server:/path/to/webdir/` in `settings.sh` or on the shell.
Then call this. It will sync everything under `images/` except for `current.img`.


## install-root-resizer.sh ##

Installs an initrd component that resizes the root fs partition and file system on boot.


## grow-image.sh ##

Usage: grow-image.sh --img-only <new_size>

Grows the size of the image, and, unless `--img-only` is specified,
 the partition on it and the file system on the partition.

Requires ruby and parted 3.x.
Must be run as root since it currently uses a loopback device to resize the FS.


## shrink-image.sh ##

Resizes the root FS to be as small as possible.
It's recommended to run `clean-image.sh` and `zerofree.sh` first.

Requires ruby and parted 3.x.
Must be run as root since it currently uses a loopback device to resize the FS.


## Making a release ##

- clean-image.sh
- zerofree.sh
- install-root-resizer.sh
- shrink-image.sh
- release.sh
- grow-image.sh  (to make the image usable in a VM again)
- test the image in a VM one more time
- rsync.sh
