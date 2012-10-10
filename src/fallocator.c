
/*
 * Replaces the fallocate(1) command, which apparently calls
 * fallocate(2) and fails on file systems not supporting the operation.
 * We call posix_fallocate(3), which seems to fall back to
 * padding the file manually.
 */

#define _FILE_OFFSET_BITS 64

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
    if (argc != 4) {
        fprintf(stderr, "Usage: fallocator <file> <offset> <len>\n");
        return 1;
    }
    
    int fd = open(argv[1], O_RDWR | O_CREAT, 0666);
    if (fd == -1) {
        perror("failed to open file");
        return 1;
    }
    uint64_t offset;
    uint64_t length;
    sscanf(argv[2], "%"SCNu64, &offset);
    sscanf(argv[3], "%"SCNu64, &length);
    
    errno = posix_fallocate(fd, offset, length);
    if (errno != 0) {
        perror("failed to fallocate");
        close(fd);
        return 1;
    }
    
    close(fd);
    
    return 0;
}
