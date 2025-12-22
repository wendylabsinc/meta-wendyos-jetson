SUMMARY = "Generate Mender artifact for Tegra UEFI Capsule Updates"
DESCRIPTION = "Creates a Mender artifact containing the UEFI capsule \
for bootloader updates on NVIDIA Tegra platforms."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit deploy

# Tegra234 (Orin) bootloader GUID
TEGRA_BL_GUID = "bf0d4599-20d4-414e-b2c5-3595b1cda402"

# Artifact naming
MENDER_CAPSULE_ARTIFACT_NAME ?= "${MACHINE}-capsule-${L4T_VERSION}"

do_compile[depends] += "tegra-uefi-capsules:do_deploy mender-artifact-native:do_populate_sysroot"

do_compile() {
    # Find the deployed capsule
    CAPSULE_FILE="${DEPLOY_DIR_IMAGE}/tegra-bl.cap"

    if [ ! -f "${CAPSULE_FILE}" ]; then
        bbwarn "tegra-bl.cap not found in ${DEPLOY_DIR_IMAGE}, skipping artifact generation"
        return 0
    fi

    # Create Mender artifact for the capsule
    mender-artifact write module-image \
        -T tegra-uefi-capsule \
        -n "${MENDER_CAPSULE_ARTIFACT_NAME}" \
        -t "${MACHINE}" \
        -o "${B}/${MENDER_CAPSULE_ARTIFACT_NAME}.mender" \
        -f "${CAPSULE_FILE}" \
        --software-filesystem uefi \
        --provides "uefi-firmware.${TEGRA_BL_GUID}.version:${L4T_VERSION}" \
        --provides "uefi-firmware.${TEGRA_BL_GUID}.name:tegra-bl" \
        --clears-provides "uefi-firmware.${TEGRA_BL_GUID}.version"
}

do_deploy() {
    if [ -f "${B}/${MENDER_CAPSULE_ARTIFACT_NAME}.mender" ]; then
        install -d ${DEPLOYDIR}
        install -m 0644 ${B}/${MENDER_CAPSULE_ARTIFACT_NAME}.mender ${DEPLOYDIR}/
    fi
}

addtask deploy after do_compile

COMPATIBLE_MACHINE = "(tegra)"
PACKAGE_ARCH = "${MACHINE_ARCH}"
