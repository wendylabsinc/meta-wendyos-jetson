FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://main.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/bluetooth
    install -m 0644 ${WORKDIR}/main.conf ${D}${sysconfdir}/bluetooth/main.conf
}

FILES:${PN} += " \
    ${sysconfdir}/bluetooth/main.conf \
    "

CONFFILES:${PN} += " \
    ${sysconfdir}/bluetooth/main.conf \
    "
