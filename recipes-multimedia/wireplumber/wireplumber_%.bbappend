# Enable WirePlumber as a system service for headless operation
SYSTEMD_SERVICE:${PN} = "wireplumber.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://50-wendy-bluetooth.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/wireplumber/wireplumber.conf.d
    install -m 0644 ${WORKDIR}/50-wendy-bluetooth.conf \
        ${D}${sysconfdir}/wireplumber/wireplumber.conf.d/50-wendy-bluetooth.conf
}

FILES:${PN} += " \
    ${sysconfdir}/wireplumber/wireplumber.conf.d/50-wendy-bluetooth.conf \
    "

CONFFILES:${PN} += " \
    ${sysconfdir}/wireplumber/wireplumber.conf.d/50-wendy-bluetooth.conf \
    "
