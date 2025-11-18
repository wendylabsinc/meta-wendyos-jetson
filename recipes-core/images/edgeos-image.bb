
DESCRIPTION = "edgeOS Image"
LICENSE = "MIT"

inherit core-image
inherit mender-full

DISTRO_FEATURES:append = " systemd"
VIRTUAL-RUNTIME_init_manager = "systemd"

# Make this image also produce an ext4 alongside tegraflash/mender/dataimg
IMAGE_FSTYPES += " ext4"

# Release-style naming for this image:
# - IMAGE_VERSION_SUFFIX is a common pattern to carry a release tag.
# - If unset, it falls back to DISTRO_VERSION.
IMAGE_VERSION_SUFFIX ?= "${DISTRO_VERSION}"

# Keep names reproducible for releases.
# (Avoid DATETIME here unless you WANT a new artifact for every rebuild.)
MENDER_ARTIFACT_NAME = "${IMAGE_BASENAME}-${MACHINE}-${IMAGE_VERSION_SUFFIX}"
# MENDER_ARTIFACT_NAME = "${IMAGE_BASENAME}-${DISTRO_VERSION}-${DATETIME}"

MENDER_UPDATE_POLL_INTERVAL_SECONDS    = "1800"
MENDER_INVENTORY_POLL_INTERVAL_SECONDS = "28800"
MENDER_RETRY_POLL_INTERVAL_SECONDS     = "300"
MENDER_SYSTEMD_AUTO_ENABLE = "1"

MENDER_CONNECT_ENABLE = "1"

# Apply our UEFI boot-priority overlay during flash
TEGRA_BOOTCONTROL_OVERLAYS += "boot-priority.dtbo"

IMAGE_FEATURES += " \
    ssh-server-openssh \
    debug-tweaks \
    "

IMAGE_INSTALL:append = " \
    packagegroup-edgeos-base \
    packagegroup-edgeos-kernel \
    packagegroup-edgeos-debug \
    mender-esp \
    mender-configure \
    mender-connect \
    tegra-bootcontrol-overlay \
    packagegroup-nvidia-container \
    nvidia-container-config \
    python3-pip-jetson-config \
    "

# Enable USB peripheral (gadget) support
IMAGE_INSTALL += " \
    ${@oe.utils.ifelse( \
        d.getVar('EDGEOS_USB_GADGET') == '1', \
            ' \
                gadget-setup \
                gadget-network-config \
                usb-gadget-modules \
                e2fsprogs-mke2fs \
                util-linux-mount \
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
