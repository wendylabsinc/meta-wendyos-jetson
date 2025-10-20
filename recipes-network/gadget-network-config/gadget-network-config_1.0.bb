
DESCRIPTION = "USB gadget network extras: dnsmasq (DHCP on usb0) and Avahi (mDNS)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://usb-gadget-dnsmasq.conf \
    file://gadget-dnsmasq.service \
    file://usb0-route-from-leases.sh \
    file://usb0-route.service \
    file://usb0-route.path \
    "

S = "${WORKDIR}"

inherit systemd

# TODO: avahi remove?
RDEPENDS:${PN} += "dnsmasq avahi-daemon"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/usb0-route-from-leases.sh ${D}${bindir}/usb0-route-from-leases.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/usb0-route.service ${D}${systemd_system_unitdir}/usb0-route.service
    install -m 0644 ${WORKDIR}/usb0-route.path    ${D}${systemd_system_unitdir}/usb0-route.path

    # dnsmasq config dedicated to usb0
    install -d ${D}${sysconfdir}/dnsmasq.d
    install -m 0644 ${WORKDIR}/usb-gadget-dnsmasq.conf ${D}${sysconfdir}/dnsmasq.d/

    # Dedicated service so we don't alter any system-wide dnsmasq config
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/gadget-dnsmasq.service ${D}${systemd_system_unitdir}/
}

CONFFILES:${PN} += "${sysconfdir}/dnsmasq.d/usb-gadget-dnsmasq.conf"

# Let the gadget unit manage dnsmasq; do NOT auto-enable the global system dnsmasq
SYSTEMD_AUTO_ENABLE:pn-dnsmasq = "disable"
SYSTEMD_AUTO_ENABLE:pn-systemd-networkd = "enable"

SYSTEMD_SERVICE:${PN} = " \
    gadget-dnsmasq.service \
    usb0-route.path \
    usb0-route.service \
    "
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

CONFFILES:${PN} += " \
    ${systemd_system_unitdir}/usb0-route.service \
    ${systemd_system_unitdir}/usb0-route.path \
    "
