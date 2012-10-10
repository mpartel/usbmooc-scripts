
all: parent-dev growpart fallocator

CFLAGS=-Wall -Os -static -m32

parent-dev: parent-dev.c
	gcc $(CFLAGS) -o $@ $<
	strip $@

growpart: growpart.c
	gcc $(CFLAGS) -o $@ $<
	strip $@

fallocator: fallocator.c
	gcc $(CFLAGS) -o $@ $<
	strip $@

clean:
	rm -f parent-dev
	rm -f growpart
	rm -f fallocator
