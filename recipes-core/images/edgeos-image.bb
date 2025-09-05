DESCRIPTION = "Edge Image with WIC support"
LICENSE = "MIT"

# require recipes-demo/images/core-image-base.bb
# require recipes-demo/images/core-image-minimal.bb
# require core-image-minimal.bb
require recipes-core/images/core-image-minimal.bb

IMAGE_FEATURES += " \
    ssh-server-openssh \
    package-management \
    "

IMAGE_INSTALL += " \
    packagegroup-edgeos-base \
    packagegroup-edgeos-debug \
    "

# IMAGE_INSTALL:append = " \
#     htop \
#     ethtool \
#     "

# A space-separated list of variable names that BitBake prints in the
# “Build Configuration” banner at the start of a build.
BUILDCFG_VARS += " \
    EDGEOS_DEBUG \
    EDGEOS_DEBUG_UART \
    EDGEOS_USB_GADGET \
    EDGEOS_PERSIST_JOURNAL_LOGS \
    "
