SUMMARY = "Mender Update Module for Tegra UEFI Capsule Updates"
DESCRIPTION = "Installs a Mender update module that handles UEFI capsule \
updates for NVIDIA Tegra platforms. This enables OTA bootloader updates \
via Mender by installing capsule files to the EFI System Partition."
HOMEPAGE = "https://github.com/wendylabsinc/meta-wendyos-jetson"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://tegra-uefi-capsule"

S = "${WORKDIR}"

RDEPENDS:${PN} = "setup-nv-boot-control"

do_install() {
    install -d ${D}${datadir}/mender/modules/v3
    install -m 0755 ${WORKDIR}/tegra-uefi-capsule ${D}${datadir}/mender/modules/v3/
}

FILES:${PN} = "${datadir}/mender/modules/v3/tegra-uefi-capsule"
