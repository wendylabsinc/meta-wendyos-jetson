
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Provide our custom /etc/hosts
SRC_URI += " \
    file://hosts \
    "

do_install:append() {
    install -m 0644 ${WORKDIR}/hosts ${D}${sysconfdir}/hosts
}

# Make it a config file so local edits survive upgrades
CONFFILES:${PN} += "${sysconfdir}/hosts"

hostname:pn-base-files = "edgeos"
