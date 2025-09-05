
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "Base support"
RDEPENDS:${PN} = " \
    packagegroup-core-boot \
    packagegroup-base-extended \
    coreutils \
    libstdc++ \
    util-linux \
    connman \
    tzdata \
    zstd \
    iproute2 \
    vim \
    htop \
    ethtool \
    "

RDEPENDS:${PN}:append = " \
    ${@oe.utils.ifelse( \
        d.getVar('EDGEOS_DEBUG') == '1', \
        ' \
            e2fsprogs-mke2fs \
        ', \
        '' \
        )} \
    "
