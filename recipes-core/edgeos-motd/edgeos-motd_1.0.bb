SUMMARY = "EdgeOS MOTD (Message of the Day) Scripts"
DESCRIPTION = "Dynamic SSH login banner with WendyOS branding, system info, and service status"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://10-edgeos-header \
    file://20-system-info \
    file://30-services \
    "

S = "${WORKDIR}"

do_install() {
    # Install update-motd.d scripts
    install -d ${D}${sysconfdir}/update-motd.d
    install -m 0755 ${WORKDIR}/10-edgeos-header ${D}${sysconfdir}/update-motd.d/
    install -m 0755 ${WORKDIR}/20-system-info ${D}${sysconfdir}/update-motd.d/
    install -m 0755 ${WORKDIR}/30-services ${D}${sysconfdir}/update-motd.d/

    # Create wrapper script to generate MOTD
    install -d ${D}${bindir}
    cat > ${D}${bindir}/update-motd << 'EOF'
#!/bin/sh
# Generate dynamic MOTD from scripts in /etc/update-motd.d/
for script in /etc/update-motd.d/*; do
    [ -x "$script" ] && "$script"
done
EOF
    chmod 0755 ${D}${bindir}/update-motd

    # Configure PAM to run update-motd on login (via profile.d)
    install -d ${D}${sysconfdir}/profile.d
    cat > ${D}${sysconfdir}/profile.d/motd.sh << 'EOF'
# Display dynamic MOTD on login
if [ -x /usr/bin/update-motd ] && [ -t 0 ]; then
    /usr/bin/update-motd
fi
EOF
    chmod 0644 ${D}${sysconfdir}/profile.d/motd.sh

    # Clear static MOTD so dynamic one shows
    install -d ${D}${sysconfdir}
    echo "" > ${D}${sysconfdir}/motd
}

FILES:${PN} = " \
    ${sysconfdir}/update-motd.d/ \
    ${sysconfdir}/profile.d/motd.sh \
    ${sysconfdir}/motd \
    ${bindir}/update-motd \
    "

RDEPENDS:${PN} = "bash"
