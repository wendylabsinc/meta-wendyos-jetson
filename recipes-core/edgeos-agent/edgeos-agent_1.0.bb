SUMMARY = "EdgeOS Agent"
DESCRIPTION = "EdgeOS agent binary for device management"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://edge-agent.service \
           file://edge-agent-updater.service \
           file://edge-agent-updater.timer \
           file://edge-agent-updater.sh"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "edge-agent.service edge-agent-updater.service edge-agent-updater.timer"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_compile() {
    bbnote "Downloading edge-agent binary for aarch64..."

    # Get the latest pre-release from GitHub
    RELEASES_URL="https://api.github.com/repos/edgeengineer/edge-agent/releases"

    # Fetch releases list
    wget -q -O ${B}/releases.json "${RELEASES_URL}" || \
        curl -sL -o ${B}/releases.json "${RELEASES_URL}" || \
        bbfatal "Failed to fetch releases from GitHub"

    # Extract download URL for aarch64 binary using simple grep (no jq dependency)
    DOWNLOAD_URL=$(cat ${B}/releases.json | \
        grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*wendy-agent-linux-static-musl-aarch64[^"]*"' | \
        head -1 | cut -d'"' -f4)

    if [ -z "${DOWNLOAD_URL}" ]; then
        bbfatal "Failed to find wendy-agent-linux-static-musl-aarch64 binary in releases"
    fi

    bbnote "Downloading from: ${DOWNLOAD_URL}"

    # Download the binary archive
    wget -O ${B}/edge-agent.tar.gz "${DOWNLOAD_URL}" || \
        curl -L -o ${B}/edge-agent.tar.gz "${DOWNLOAD_URL}" || \
        bbfatal "Failed to download edge-agent binary"

    # Extract the archive
    tar -xzf ${B}/edge-agent.tar.gz -C ${B}

    # Find and prepare the binary
    if [ ! -f ${B}/wendy-agent ]; then
        BINARY=$(find ${B} -name wendy-agent -type f ! -path "*/edge-cli*" | head -1)
        if [ -n "${BINARY}" ]; then
            mv "${BINARY}" ${B}/wendy-agent
        else
            bbfatal "wendy-agent binary not found in archive"
        fi
    fi

    chmod +x ${B}/wendy-agent
    bbnote "wendy-agent binary ready"
}

do_install() {
    # Install the pre-downloaded binary
    install -d ${D}/usr/local/bin
    install -m 0755 ${B}/wendy-agent ${D}/usr/local/bin/wendy-agent

    # Install systemd services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edge-agent.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/edge-agent-updater.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/edge-agent-updater.timer ${D}${systemd_system_unitdir}/

    # Install updater script
    install -d ${D}/opt/edgeos/bin
    install -m 0755 ${WORKDIR}/edge-agent-updater.sh ${D}/opt/edgeos/bin/

    # Create runtime directory
    install -d ${D}/var/lib/edge-agent
}

FILES:${PN} = "/usr/local/bin/* \
               /opt/edgeos/bin/* \
               ${systemd_system_unitdir}/* \
               /var/lib/edge-agent"

# Allow network access during build
do_compile[network] = "1"

# Skip QA checks for pre-built binary
INSANE_SKIP:${PN} += "already-stripped"

# Runtime dependencies
RDEPENDS:${PN} = "bash"