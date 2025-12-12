SUMMARY = "NVIDIA Container Configuration for Jetson"
DESCRIPTION = "Provides l4t.csv configuration, CDI spec generation, and CUDA environment detection for NVIDIA GPU containers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://l4t.csv \
    file://devices-sysfs.csv \
    file://edgeos-cdi-generate.service \
    file://edgeos-cuda-detect.service \
    file://generate-cuda-env.sh \
    file://99-z-nvidia-tegra.rules \
    "

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "edgeos-cdi-generate.service edgeos-cuda-detect.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install CSV files to the NVIDIA container runtime config directory
    install -d ${D}${sysconfdir}/nvidia-container-runtime/host-files-for-container.d
    install -m 0644 ${WORKDIR}/l4t.csv ${D}${sysconfdir}/nvidia-container-runtime/host-files-for-container.d/
    install -m 0644 ${WORKDIR}/devices-sysfs.csv ${D}${sysconfdir}/nvidia-container-runtime/host-files-for-container.d/

    # Install CUDA environment detection script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/generate-cuda-env.sh ${D}${bindir}/

    # Install systemd services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-cdi-generate.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/edgeos-cuda-detect.service ${D}${systemd_system_unitdir}/

    # Install udev rules for GPU device permissions (z- prefix ensures it runs last)
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/99-z-nvidia-tegra.rules ${D}${sysconfdir}/udev/rules.d/

    # Create directory for CUDA environment file
    install -d ${D}${sysconfdir}/default
}

FILES:${PN} += "${sysconfdir}/nvidia-container-runtime/host-files-for-container.d/l4t.csv"
FILES:${PN} += "${sysconfdir}/nvidia-container-runtime/host-files-for-container.d/devices-sysfs.csv"
FILES:${PN} += "${bindir}/generate-cuda-env.sh"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-cdi-generate.service"
FILES:${PN} += "${systemd_system_unitdir}/edgeos-cuda-detect.service"
FILES:${PN} += "${sysconfdir}/udev/rules.d/99-z-nvidia-tegra.rules"

# nvidia-container-toolkit is now available via meta-tegra virtualization layer
RDEPENDS:${PN} = "nvidia-container-toolkit libnvidia-container bash"
