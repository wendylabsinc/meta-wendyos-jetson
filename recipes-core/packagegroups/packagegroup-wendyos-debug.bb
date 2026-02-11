
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "Debugging package group"
RDEPENDS:${PN} = " \
    ${@oe.utils.ifelse( \
        d.getVar('WENDYOS_DEBUG') == '1', \
        ' \
            mmc-utils \
            fio \
            memtester \
            gperftools \
            bash \
            rt-tests \
            nfs-utils \
            procps \
            sysstat \
            ldd \
            bc  \
            python3-jetson-stats \
        ', \
        '' \
        )} \
    "
