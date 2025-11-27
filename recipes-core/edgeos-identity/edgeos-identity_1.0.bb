SUMMARY = "EdgeOS Device Identity Management"
DESCRIPTION = "Generates and manages unique device UUID and device name for EdgeOS devices"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://generate-uuid.sh \
    file://generate-device-name.sh \
    file://update-mdns-uuid.sh \
    file://edgeos-uuid-generate.service \
    file://edgeos-device-name-generate.service \
    file://edgeos-identity.service \
    file://adjectives.txt \
    file://nouns.txt \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-uuid-generate.service edgeos-device-name-generate.service edgeos-identity.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install scripts to /usr/bin
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/generate-uuid.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/generate-device-name.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/update-mdns-uuid.sh ${D}${bindir}/

    # Install word lists for device name generation
    install -d ${D}${datadir}/edgeos
    install -m 0644 ${WORKDIR}/adjectives.txt ${D}${datadir}/edgeos/
    install -m 0644 ${WORKDIR}/nouns.txt ${D}${datadir}/edgeos/

    # Install systemd services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-uuid-generate.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/edgeos-device-name-generate.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/edgeos-identity.service ${D}${systemd_system_unitdir}/

    # Create directory for identity storage
    install -d ${D}${sysconfdir}/edgeos

    # Create Wendy/WendyOS version file
    install -d ${D}${sysconfdir}/wendy
    echo "WendyOS-${DISTRO_VERSION}" > ${WORKDIR}/version.txt
    install -m 0644 ${WORKDIR}/version.txt ${D}${sysconfdir}/wendy/version.txt

    # Create build ID file (actual date will be set at first boot if needed)
    echo "WendyOS-${DISTRO_VERSION}" > ${WORKDIR}/edgeos-build-id
    install -m 0644 ${WORKDIR}/edgeos-build-id ${D}${sysconfdir}/edgeos-build-id
}

FILES:${PN} += "${bindir}/generate-uuid.sh"
FILES:${PN} += "${bindir}/generate-device-name.sh"
FILES:${PN} += "${bindir}/update-mdns-uuid.sh"
FILES:${PN} += "${datadir}/edgeos/adjectives.txt"
FILES:${PN} += "${datadir}/edgeos/nouns.txt"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-uuid-generate.service"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-device-name-generate.service"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-identity.service"
FILES:${PN} += "${sysconfdir}/edgeos"
FILES:${PN} += "${sysconfdir}/wendy/version.txt"
FILES:${PN} += "${sysconfdir}/edgeos-build-id"

RDEPENDS:${PN} = "bash util-linux-uuidgen avahi-daemon coreutils iproute2"