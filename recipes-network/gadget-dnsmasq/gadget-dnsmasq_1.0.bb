
SUMMARY = "Set default route via USB host using dnsmasq lease hook"
DESCRIPTION = "dnsmasq dhcp-script on usb0 sets 'ip route replace default via <host-ip> dev usb0'."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://gadget-dnsmasq-hook.sh \
    file://gadget-dnsmasq-hook.conf \
    "
S = "${WORKDIR}"

RDEPENDS:${PN} += "dnsmasq iproute2 bash"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/gadget-dnsmasq-hook.sh ${D}${bindir}/

    install -d ${D}${sysconfdir}/dnsmasq.d
    install -m 0644 ${WORKDIR}/gadget-dnsmasq-hook.conf ${D}${sysconfdir}/dnsmasq.d/
}

CONFFILES:${PN} += "${sysconfdir}/dnsmasq.d/gadget-dnsmasq-hook.conf"
