// jetson-reboot-mode.c
// SPDX-License-Identifier: MIT
//
// Helper to reboot Jetson into special modes like "forced-recovery"
// Works with NVIDIA / meta-tegra L4T kernels that have Tegra PMC reboot support.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/reboot.h>
#include <errno.h>

static void usage(const char *prog)
{
    fprintf(stderr,
        "Usage: %s MODE\n"
        "  MODE can be: recovery | bootloader | forced-recovery\n",
        prog);
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        usage(argv[0]);
        return 1;
    }

    const char *mode = argv[1];

    if (strcmp(mode, "recovery") &&
        strcmp(mode, "bootloader") &&
        strcmp(mode, "forced-recovery")) {
        fprintf(stderr, "Unsupported mode '%s'\n", mode);
        usage(argv[0]);
        return 1;
    }

    printf("Rebooting into '%s'...\n", mode);
    fflush(stdout);
    sync();

    int ret = syscall(SYS_reboot,
                      LINUX_REBOOT_MAGIC1,
                      LINUX_REBOOT_MAGIC2,
                      LINUX_REBOOT_CMD_RESTART2,
                      (void *)mode);
    if (ret < 0) {
        perror("reboot");
        return errno;
    }

    return 0;
}
