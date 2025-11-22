SUMMARY = "WendyOS Development Container Registry Image"
DESCRIPTION = "Pre-built container image for the WendyOS development registry"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

PV = "1.0.0"

# Download the container image tar from GitHub releases
# BitBake will automatically unpack the .tar.gz to get the .tar file
SRC_URI = "https://github.com/mihai-chiorean/containerd-registry/releases/download/v${PV}/containerd-registry-arm64.tar.gz"

# Checksum for v1.0.0 release
SRC_URI[sha256sum] = "0ea9497b4fd3b6ed3a2b61bae71d27c595c058a72d76621379ef56fe6c8b5073"

inherit allarch

S = "${WORKDIR}"

# Directory where offline images are stored
OFFLINE_IMAGES_DIR = "${datadir}/edgeos/offline-images"

do_install() {
    install -d ${D}${OFFLINE_IMAGES_DIR}
    # Install the tar file (BitBake already extracted it from the .tar.gz)
    install -m 0644 ${WORKDIR}/containerd-registry-arm64.tar ${D}${OFFLINE_IMAGES_DIR}/
}

FILES:${PN} = "${OFFLINE_IMAGES_DIR}/containerd-registry-arm64.tar"

# This package only contains a container image archive
ALLOW_EMPTY:${PN} = "0"

# Skip QA checks for this special package
INSANE_SKIP:${PN} = "arch"
