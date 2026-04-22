#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
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

static unsigned long parse_limit(const char *value) {
    char *end = NULL;
    unsigned long parsed;

    if (value == NULL || *value == '\0') {
        return 0;
    }
    parsed = strtoul(value, &end, 10);
    if (end == NULL || *end != '\0') {
        fprintf(stderr, "invalid iteration limit: %s\n", value);
        exit(2);
    }
    return parsed;
}

int main(int argc, char **argv) {
    const char *left;
    const char *right;
    unsigned long limit;
    unsigned long i = 0;

    if (argc < 3 || argc > 4) {
        fprintf(stderr, "usage: %s <left> <right> [iteration_limit]\n", argv[0]);
        return 2;
    }

    left = argv[1];
    right = argv[2];
    limit = argc == 4 ? parse_limit(argv[3]) : 0;

    for (;;) {
        if (syscall(SYS_renameat2, AT_FDCWD, left, AT_FDCWD, right,
                    RENAME_EXCHANGE) != 0) {
            fprintf(stderr, "renameat2 exchange failed: %s\n", strerror(errno));
            return 1;
        }
        i++;
        if (limit != 0 && i >= limit) {
            break;
        }
    }

    return 0;
}
