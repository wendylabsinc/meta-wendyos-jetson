
DESCRIPTION = "edgeOS Image"
LICENSE = "MIT"

inherit core-image

DISTRO_FEATURES:append = " systemd"
VIRTUAL-RUNTIME_init_manager = "systemd"

IMAGE_FEATURES += " \
    ssh-server-openssh \
    "

IMAGE_INSTALL:append = " \
    packagegroup-edgeos-base \
    packagegroup-edgeos-kernel \
    packagegroup-edgeos-debug \
    "

# Enable USB peripheral (gadget) support
IMAGE_INSTALL += " \
    ${@oe.utils.ifelse( \
        d.getVar('EDGEOS_USB_GADGET') == '1', \
            ' \
                gadget-setup \
                gadget-network \
                gadget-network-config \
                gadget-dnsmasq \
                usb-gadget-modules \
                e2fsprogs-mke2fs \
                util-linux-mount \
                awk \
            ', \
            '' \
        )} \
    "

IMAGE_ROOTFS_SIZE ?= "8192"
IMAGE_ROOTFS_EXTRA_SPACE:append = "${@bb.utils.contains("DISTRO_FEATURES", "systemd", " + 4096", "", d)}"

# A space-separated list of variable names that BitBake prints in the
# “Build Configuration” banner at the start of a build.
BUILDCFG_VARS += " \
    EDGEOS_DEBUG \
    EDGEOS_DEBUG_UART \
    EDGEOS_USB_GADGET \
    EDGEOS_PERSIST_JOURNAL_LOGS \
    "
