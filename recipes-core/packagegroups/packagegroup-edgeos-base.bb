
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "Base support"
RDEPENDS:${PN} = " \
    packagegroup-core-boot \
    tegra-flash-reboot \
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
    util-linux-fdisk \
    avahi-daemon \
    avahi-edgeos-hostname \
    avahi-utils \
    k3s-agent \
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
