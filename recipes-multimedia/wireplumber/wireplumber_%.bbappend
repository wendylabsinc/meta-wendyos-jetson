# Enable WirePlumber as a system service for headless operation
SYSTEMD_SERVICE:${PN} = "wireplumber.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://50-wendy-bluetooth.conf \
            file://60-wendy-defaults.conf \
            file://wendy-default-nodes.lua \
            file://wireplumber.service.d/override.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/wireplumber/wireplumber.conf.d
    install -m 0644 ${WORKDIR}/50-wendy-bluetooth.conf \
        ${D}${sysconfdir}/wireplumber/wireplumber.conf.d/50-wendy-bluetooth.conf
    install -m 0644 ${WORKDIR}/60-wendy-defaults.conf \
        ${D}${sysconfdir}/wireplumber/wireplumber.conf.d/60-wendy-defaults.conf

    install -d ${D}${datadir}/wireplumber/scripts/wendy
    install -m 0644 ${WORKDIR}/wendy-default-nodes.lua \
        ${D}${datadir}/wireplumber/scripts/wendy/default-nodes.lua

    install -d ${D}${sysconfdir}/systemd/system/wireplumber.service.d
    install -m 0644 ${WORKDIR}/wireplumber.service.d/override.conf \
        ${D}${sysconfdir}/systemd/system/wireplumber.service.d/override.conf
}

FILES:${PN} += " \
    ${sysconfdir}/wireplumber/wireplumber.conf.d/50-wendy-bluetooth.conf \
    ${sysconfdir}/wireplumber/wireplumber.conf.d/60-wendy-defaults.conf \
    ${datadir}/wireplumber/scripts/wendy/default-nodes.lua \
    ${sysconfdir}/systemd/system/wireplumber.service.d/override.conf \
    "

CONFFILES:${PN} += " \
    ${sysconfdir}/wireplumber/wireplumber.conf.d/50-wendy-bluetooth.conf \
    ${sysconfdir}/wireplumber/wireplumber.conf.d/60-wendy-defaults.conf \
    ${sysconfdir}/systemd/system/wireplumber.service.d/override.conf \
    "
