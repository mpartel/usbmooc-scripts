
#define _FILE_OFFSET_BITS 64
#define _BSD_SOURCE

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>


int main(int argc, const char *argv[])
{
    if (argc != 2) {
        fprintf(stderr, "Usage: parent-dev <dev>\n");
        return 1;
    }

    struct stat st;
    if (stat(argv[1], &st) == -1) {
        perror("cannot stat device");
        return 1;
    }

    if (!S_ISBLK(st.st_mode)) {
        fprintf(stderr, "Not a block device: %s\n", argv[1]);
        return 1;
    }

    int maj = major(st.st_rdev);
    int min = minor(st.st_rdev);

    int minors_per_disk;

    switch (maj) {
    /* /dev/hdX */
    case 3:
        minors_per_disk = 32;
        break;
    /* /dev/sdX or other with 15 partitions. Not an exhaustive list. */
    case 8:
    case 65:
    case 66:
    case 67:
    case 68:
    case 69:
    case 70:
    case 71:
    case 98:
    case 102:
    case 112:
    case 202:
        minors_per_disk = 16;
        break;
    default:
        fprintf(stderr, "Unknown device: %s (%d:%d)\n", argv[1], maj, min);
        return 1;
    }

    int part_num = min % minors_per_disk;
    int wanted_min = min - part_num;

    char command[1024];
    sprintf(command, "find /dev -type b -exec stat -c \"%%t:%%T %%n\" '{}' ';' | grep -E '^%x:%x' | sed 's/^[0-9]*:[0-9]* //'", maj, wanted_min);
    return system(command);
}
