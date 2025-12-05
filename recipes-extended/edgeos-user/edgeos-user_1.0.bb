SUMMARY = "EdgeOS Default User Configuration"
DESCRIPTION = "Creates the default 'edge' user with appropriate permissions for EdgeOS. \
Home directory is initialized on first boot from persistent storage (/data/home)."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit useradd systemd

SRC_URI = " \
    file://edgeos-user-setup.sh \
    file://edgeos-user-setup.service \
"

# Create edge user - simplified group list (non-existent groups cause failures)
USERADD_PACKAGES = "${PN}"
# Password 'edge' hash generated with: openssl passwd -6 -salt 5ixFr0sKRtsKKKhY edge
# NOTE: useradd with -m flag will try to create home, but since /home is bind-mounted
# from /data/home, the actual initialization happens via first-boot service
USERADD_PARAM:${PN} = "-m -d /home/edge -s /bin/bash -G dialout,video,audio,users -p '\$6\$5ixFr0sKRtsKKKhY\$NBU4Np0LBKjFMFZ5BpJr8wLT5UvTpY1cVFGdUWMCs0m4UDGMTHlU2efR6Qfwq5BMtCq8wqN.RoZH/vEt/cuyE1' edge"

SYSTEMD_SERVICE:${PN} = "edgeos-user-setup.service"
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    # Install first-boot setup script
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/edgeos-user-setup.sh ${D}${sbindir}/edgeos-user-setup.sh

    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-user-setup.service ${D}${systemd_system_unitdir}/edgeos-user-setup.service
}

pkg_postinst_ontarget:${PN}() {
    # Add sudoers entry for edge user on target only
    if [ -d /etc/sudoers.d ]; then
        echo "edge ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/edge
        chmod 0440 /etc/sudoers.d/edge
    fi
}

FILES:${PN} += " \
    ${sbindir}/edgeos-user-setup.sh \
    ${systemd_system_unitdir}/edgeos-user-setup.service \
"

# Ensure required packages are available
# systemd-mount-home provides the /home bind mount
RDEPENDS:${PN} = "sudo bash systemd systemd-mount-home"
