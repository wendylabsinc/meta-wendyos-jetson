
PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

SUMMARY:${PN} = "Debugging package group"
RDEPENDS:${PN} = " \
    ${@oe.utils.ifelse( \
        d.getVar('EDGEOS_DEBUG') == '1', \
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
        ', \
        '' \
        )} \
    "
