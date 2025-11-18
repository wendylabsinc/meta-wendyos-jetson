SUMMARY = "NVIDIA Container Configuration for Jetson"
DESCRIPTION = "Provides l4t.csv configuration and CDI spec generation for NVIDIA GPU containers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://l4t.csv \
    file://edgeos-cdi-generate.service \
    file://99-nvidia-tegra.rules \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-cdi-generate.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install l4t.csv to the NVIDIA container runtime config directory
    install -d ${D}${sysconfdir}/nvidia-container-runtime/host-files-for-container.d
    install -m 0644 ${WORKDIR}/l4t.csv ${D}${sysconfdir}/nvidia-container-runtime/host-files-for-container.d/

    # Install systemd service for CDI generation
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-cdi-generate.service ${D}${systemd_system_unitdir}/

    # Install udev rules for GPU device permissions
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/99-nvidia-tegra.rules ${D}${sysconfdir}/udev/rules.d/
}

FILES:${PN} += "${sysconfdir}/nvidia-container-runtime/host-files-for-container.d/l4t.csv"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-cdi-generate.service"
FILES:${PN} += "${sysconfdir}/udev/rules.d/99-nvidia-tegra.rules"

# nvidia-container-toolkit is now available via meta-tegra virtualization layer
RDEPENDS:${PN} = "nvidia-container-toolkit libnvidia-container"
