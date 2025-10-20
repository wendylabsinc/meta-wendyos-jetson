
SUMMARY = "systemd-networkd config for usb0 (gadget)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    file://10-gadget.network \
    "
S = "${WORKDIR}"

RDEPENDS:${PN} += " \
    iproute2 \
    "

# systemd-networkd

# Install the .network file
do_install() {
    install -d ${D}${sysconfdir}/systemd/network
    install -m 0644 ${WORKDIR}/10-gadget.network ${D}${sysconfdir}/systemd/network/
}

# Mark it as a config file so user edits are preserved across updates
CONFFILES:${PN} += "${sysconfdir}/systemd/network/10-gadget.network"
