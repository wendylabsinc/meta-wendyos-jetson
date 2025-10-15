
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "Base support"
RDEPENDS:${PN} = " \
    packagegroup-core-boot \
    bash \
    coreutils \
    libstdc++ \
    file \
    util-linux \
    iproute2 \
    vim \
    htop \
    usbutils \
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
