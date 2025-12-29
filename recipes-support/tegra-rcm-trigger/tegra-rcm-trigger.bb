SUMMARY = "Jetson reboot mode utility"
DESCRIPTION = "Tool to reboot Jetson into special modes (recovery, bootloader) using kernel reboot syscall"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://tegra-rcm-trigger.c"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -o tegra-rcm-trigger tegra-rcm-trigger.c
}

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 tegra-rcm-trigger ${D}${sbindir}/
}

FILES:${PN} = "${sbindir}/tegra-rcm-trigger"

COMPATIBLE_MACHINE = "jetson-orin-nano-devkit-.*"
