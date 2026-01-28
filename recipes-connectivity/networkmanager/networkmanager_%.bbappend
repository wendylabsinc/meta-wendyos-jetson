
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Install NetworkManager configuration files
SRC_URI += " \
    file://NetworkManager.conf \
    file://00-manage-usb0.conf \
    file://10-usb-gadget-shared.conf \
    file://usb-gadget.nmconnection \
    file://99-interface-metrics.conf \
    "

# Install main NetworkManager configuration
do_install:append() {
    # Install main config
    install -d ${D}${sysconfdir}/NetworkManager
    install -m 0644 ${WORKDIR}/NetworkManager.conf ${D}${sysconfdir}/NetworkManager/NetworkManager.conf

    # Install NetworkManager config drop-ins
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -m 0644 ${WORKDIR}/00-manage-usb0.conf ${D}${sysconfdir}/NetworkManager/conf.d/00-manage-usb0.conf
    install -m 0644 ${WORKDIR}/10-usb-gadget-shared.conf ${D}${sysconfdir}/NetworkManager/conf.d/10-usb-gadget-shared.conf
    install -m 0644 ${WORKDIR}/99-interface-metrics.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-interface-metrics.conf

    # Install system connections (USB gadget profile)
    install -d ${D}${sysconfdir}/NetworkManager/system-connections
    install -m 0600 ${WORKDIR}/usb-gadget.nmconnection ${D}${sysconfdir}/NetworkManager/system-connections/usb-gadget.nmconnection
}

# Make sure our config files are packaged
FILES:${PN} += " \
    ${sysconfdir}/NetworkManager/NetworkManager.conf \
    ${sysconfdir}/NetworkManager/conf.d/00-manage-usb0.conf \
    ${sysconfdir}/NetworkManager/conf.d/10-usb-gadget-shared.conf \
    ${sysconfdir}/NetworkManager/conf.d/99-interface-metrics.conf \
    ${sysconfdir}/NetworkManager/system-connections/usb-gadget.nmconnection \
    "

# Ensure NetworkManager starts after USB gadget is set up
SYSTEMD_AUTO_ENABLE = "enable"

# dnsmasq required for connection sharing (ipv4.method=shared)
RDEPENDS:${PN} += "dnsmasq"
