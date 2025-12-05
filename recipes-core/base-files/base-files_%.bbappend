
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Provide our custom /etc/hosts and profile.d defaults
SRC_URI += " \
    file://hosts \
    file://profile.d/edgeos-defaults.sh \
    "

do_install:append() {
    install -m 0644 ${WORKDIR}/hosts ${D}${sysconfdir}/hosts

    # Install profile.d defaults
    install -d ${D}${sysconfdir}/profile.d
    install -m 0755 ${WORKDIR}/profile.d/edgeos-defaults.sh ${D}${sysconfdir}/profile.d/edgeos-defaults.sh
}

# Make it a config file so local edits survive upgrades
CONFFILES:${PN} += "${sysconfdir}/hosts"

hostname:pn-base-files = "edgeos"
