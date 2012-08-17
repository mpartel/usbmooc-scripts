
OUT=build

BUSYBOX_VERSION=1.20.2
KERNEL_VERSION=3.4.9

.NOTPARALLEL:

ifeq ($(SUBMAKE_JOBS),)
  SUBMAKE_JOBS=3
endif

dummy_create_output_dir := $(shell test -d $(OUT) || mkdir -p $(OUT))

all: initrd kernel

kernel: $(OUT)/linux.uml

$(OUT)/linux.uml: $(OUT)/linux-$(KERNEL_VERSION)/.config
	cd $(OUT)/linux-$(KERNEL_VERSION) && make -j$(SUBMAKE_JOBS) ARCH=um SUBARCH=i386
	cp -f $(OUT)/linux-$(KERNEL_VERSION)/linux $@

$(OUT)/linux-$(KERNEL_VERSION)/.config: kernel-config $(OUT)/linux-$(KERNEL_VERSION)/Makefile
	cp $< $@

$(OUT)/linux-$(KERNEL_VERSION)/Makefile: $(OUT)/linux-$(KERNEL_VERSION).tar.bz2
	tar -C $(OUT) -xvjf $(OUT)/linux-$(KERNEL_VERSION).tar.bz2
	touch $@

$(OUT)/linux-$(KERNEL_VERSION).tar.bz2:
	wget -O $@ http://www.kernel.org/pub/linux/kernel/v3.0/linux-$(KERNEL_VERSION).tar.bz2


# Busybox
BUSYBOX_INSTALL_DIR=$(OUT)/busybox-$(BUSYBOX_VERSION)/_install
busybox: $(BUSYBOX_INSTALL_DIR)/bin/busybox

$(BUSYBOX_INSTALL_DIR)/bin/busybox: $(OUT)/busybox-$(BUSYBOX_VERSION) busybox-config
	cp busybox-config $(OUT)/busybox-$(BUSYBOX_VERSION)/.config
	make -C $(OUT)/busybox-$(BUSYBOX_VERSION) -j$(SUBMAKE_JOBS) CFLAGS="-m32" LDFLAGS="-Xlinker -m -Xlinker elf_i386"
	make -C $(OUT)/busybox-$(BUSYBOX_VERSION) install CFLAGS="-m32" LDFLAGS="-Xlinker -m -Xlinker elf_i386"

$(OUT)/busybox-$(BUSYBOX_VERSION): $(OUT)/busybox-$(BUSYBOX_VERSION).tar.bz2
	tar -C $(OUT) -xvjf $(OUT)/busybox-$(BUSYBOX_VERSION).tar.bz2

$(OUT)/busybox-$(BUSYBOX_VERSION).tar.bz2:
	wget -O $@ http://busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2


# Initrd
initrd: $(OUT)/initrd.img

$(OUT)/initrd.img: $(OUT)/initrd/init
	cd $(OUT)/initrd && mkdir -p proc sys tmp var
	cd $(OUT)/initrd && find . | cpio --quiet -H newc -o | gzip > ../initrd.img

$(OUT)/initrd/init: $(BUSYBOX_INSTALL_DIR)/bin/busybox initrd-init-script
	mkdir -p $(OUT)/initrd
	cp -a $(BUSYBOX_INSTALL_DIR)/* $(OUT)/initrd/
	cp initrd-init-script $(OUT)/initrd/init
	chmod +x $(OUT)/initrd/init


clean: clean-busybox clean-initrd

distclean:
	rm -Rf $(OUT)

clean-busybox:
	rm -Rf $(OUT)/busybox-$(BUSYBOX_VERSION)
	rm -Rf $(OUT)/busybox-$(BUSYBOX_VERSION).tar.bz2

distclean-busybox: clean-busybox

clean-initrd:
	rm -Rf $(OUT)/initrd

distclean-initrd: clean-initrd
	$(OUT)/initrd.img

