
/*
 * Grows the first partition of the given disk
 * to be as large as possible.
 *
 * When called with --check, exits with 0 immediately
 * if there is room to grow the partition, else with 2.
 */

#define _FILE_OFFSET_BITS 64

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <linux/fs.h>

#ifndef __BYTE_ORDER__
#error "__BYTE_ORDER__ not defined"
#endif
#if __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
#error "This program only works on a little endian architecture"
#endif

#define MIN(x, y) (((x) < (y)) ? (x) : (y))
#define MAX(x, y) (((x) > (y)) ? (x) : (y))

/*
 * The MBR layout is described clearly e.g. here: http://en.wikipedia.org/wiki/MBR_partition_table
 */

static const int boot_sig_offset = 0x1FE;
static const int part_table_offset = 0x1BE;
static const int part_record_length = 16;

static void lba_to_chs(uint32_t lba, uint8_t *chs) {
    /* http://en.wikipedia.org/wiki/Logical_Block_Addressing#CHS_conversion */
    uint32_t hpc = 255;
    uint32_t spt = 63;
    uint32_t c = MIN(lba / (spt * hpc), 1023);
    uint32_t h = (lba / spt) % hpc;
    uint32_t s = (lba % spt) + 1;
    printf("CHS = %u %u %u %u\n", lba / (spt * hpc), c, h, s);
    chs[0] = h;
    chs[1] = (((c & 0x300) >> 8) << 6) | (s & 0x3F);
    chs[2] = c & 0xFF;
}

int main(int argc, const char* argv[]) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "Usage: growpart [--check] <device>\n");
        return 1;
    }

    int check_only = 0;
    const char *device;

    if (argc == 3) {
        if (strcmp(argv[1], "--check") == 0) {
            check_only = 1;
            device = argv[2];
        } else {
            fprintf(stderr, "unrecognized option: %s\n", argv[1]);
            return 1;
        }
    } else {
        device = argv[1];
    }
    
    int fd = open(device, O_RDWR);
    if (fd == -1) {
        perror("failed to open file");
        return 1;
    }
    
    off_t dev_size = lseek(fd, 0, SEEK_END);
    if (dev_size == -1) {
        perror("failed to seek to end of file");
        close(fd);
        return 1;
    }
    if (lseek(fd, 0, SEEK_SET) == -1) {
        perror("failed to seek to start of file");
        close(fd);
        return 1;
    }
    
    uint8_t mbr[512];
    ssize_t amt_read = read(fd, mbr, 512);
    if (amt_read != 512) {
        fprintf(stderr, "Failed to read MBR\n");
        close(fd);
        return 1;
    }

    if (mbr[boot_sig_offset] != 0x55 || mbr[boot_sig_offset + 1] != 0xAA) {
        fprintf(stderr, "MBR boot signature not present\n");
        close(fd);
        return 1;
    }
    
    uint8_t part_types[4];
    uint32_t part_offsets[4];
    uint32_t part_lengths[4];
    int i;
    for (i = 0; i < 4; ++i) {
        int offset = part_table_offset + i * part_record_length;
        part_types[i] = mbr[offset + 0x04];
        /* We required a little endian architecture above,
           so it's safe to read little-endian ints directly. */
        part_offsets[i] = *(uint32_t*)&mbr[offset + 0x08];
        part_lengths[i] = *(uint32_t*)&mbr[offset + 0x0C];
    }
    
    if (dev_size / 512 > UINT32_MAX) {
        fprintf(stderr, "Disk too large");
        close(fd);
        return 0;
    }
    
    const int padding = 1;
    uint32_t limit = (uint32_t)(dev_size / 512) - padding;
    for (i = 1; i < 4; ++i) {
        if (part_types[i] != 0 && part_offsets[i] != 0) {
            limit = MIN(limit, part_offsets[i] - 1);
        }
    }
    
    if (limit <= part_offsets[0] + part_lengths[0]) {
        if (check_only) {
            close(fd);
            return 2;
        }
        fprintf(stderr, "Partition already at maximum size.\n");
        close(fd);
        return 0;
    }

    if (check_only) {
        close(fd);
        return 0;
    }
    
    if (lseek(fd, 0, SEEK_SET) == -1) {
        perror("failed to seek to start of file");
        close(fd);
        return 1;
    }
    
    printf("Resizing first partition to end at block %"PRIu32" (%"PRIu64" bytes)\n", limit, (uint64_t)limit * 512);
    lba_to_chs(limit, &mbr[part_table_offset + 0x05]);
    *(uint32_t*)&mbr[part_table_offset + 0x0C] = limit - part_offsets[0];
    if (write(fd, mbr, 512) != 512) {
        fprintf(stderr, "Failed to write back MBR.\n");
        close(fd);
        return 1;
    }

    sync();
    sleep(1);
    for (i = 0; i < 10; ++i) {
      if (ioctl(fd, BLKRRPART, NULL) >= 0) {
          break;
      } else {
          perror("warning: failed to reread partition table");
          sleep(1);
      }
    }
    
    close(fd);
    return 0;
}
