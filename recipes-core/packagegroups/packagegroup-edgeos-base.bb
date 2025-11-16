
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "Base support"
RDEPENDS:${PN} = " \
    packagegroup-core-boot \
    bash \
    efibootmgr \
    coreutils \
    libstdc++ \
    file \
    util-linux \
    iproute2 \
    vim \
    htop \
    usbutils \
    tree \
    avahi-daemon \
    avahi-utils \
    edgeos-identity \
    edgeos-agent \
    edgeos-user \
    "

RDEPENDS:${PN}:append = " \
    ${@oe.utils.ifelse( \
        d.getVar('EDGEOS_DEBUG') == '1', \
        ' \
            \
        ', \
        '' \
        )} \
    "
