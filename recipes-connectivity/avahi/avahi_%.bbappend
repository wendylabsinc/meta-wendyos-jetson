
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://edgeos-mdns.service \
    file://generate-hostname.sh \
    file://edgeos-hostname.service \
    file://nsswitch.conf.append \
    file://90-edgeos.preset \
    "

# Ensure D-Bus support is enabled for proper service publishing
PACKAGECONFIG += "dbus"

# Ensure Avahi compiles with static service file support
EXTRA_OECONF += " \
    --with-avahi-user=avahi \
    --with-avahi-group=avahi \
    "

inherit systemd

do_install:append() {
    # Install hostname generation script + systemd unit (goes to sub-package)
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/generate-hostname.sh ${D}${sbindir}/

    # Install Avahi service file
    install -d ${D}${sysconfdir}/avahi/services
    install -m 0644 ${WORKDIR}/edgeos-mdns.service ${D}${sysconfdir}/avahi/services/

    # Install systemd service for hostname setup
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/edgeos-hostname.service ${D}${systemd_system_unitdir}/

    # Ensure NSS mDNS is properly configured
    if [ -f "${D}${sysconfdir}/nsswitch.conf" ]
    then
        # Check if mdns is already configured
        if ! grep -q "mdns" "${D}${sysconfdir}/nsswitch.conf"
        then
            # Replace the hosts line with our configuration
            sed -i '/^hosts:/d' "${D}${sysconfdir}/nsswitch.conf"
            cat "${WORKDIR}/nsswitch.conf.append" >> "${D}${sysconfdir}/nsswitch.conf"
        fi
    fi

    # Enable Avahi daemon and ensure it starts with proper settings
    if [ -f "${D}${sysconfdir}/avahi/avahi-daemon.conf" ]
    then
        # Enable D-Bus support for proper service publishing
        sed -i 's/^#*enable-dbus=.*/enable-dbus=yes/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"

        # Enable mDNS reflector for better discovery
        sed -i 's/^#*enable-reflector=.*/enable-reflector=yes/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"

        # Set proper hostname behavior
        sed -i 's/^#*use-ipv4=.*/use-ipv4=yes/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"
        sed -i 's/^#*use-ipv6=.*/use-ipv6=yes/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"

        # Enable publishing
        sed -i 's/^#*publish-addresses=.*/publish-addresses=yes/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"
        sed -i 's/^#*publish-hinfo=.*/publish-hinfo=yes/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"
        sed -i 's/^#*publish-workstation=.*/publish-workstation=yes/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"
        sed -i 's/^#*publish-domain=.*/publish-domain=yes/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"

        # Set host name
        sed -i 's/^#*host-name=.*/# host-name is set dynamically by edgeos-hostname.service/' "${D}${sysconfdir}/avahi/avahi-daemon.conf"
    fi

    # Systemd preset to auto-enable hostname service by default
    install -d ${D}${systemd_unitdir}/system-preset
    install -m 0644 ${WORKDIR}/90-edgeos.preset \
        ${D}${systemd_unitdir}/system-preset/90-edgeos.preset
}

# --- What remains in the avahi main package (ONLY the .service for mDNS) ---
FILES:${PN} += " ${sysconfdir}/avahi/services/edgeos-mdns.service "

# --- Sub-package for EdgeOS hostname setup ---
PACKAGES:prepend = "${PN}-edgeos-hostname "
FILES:${PN}-edgeos-hostname = " \
    ${sbindir}/generate-hostname.sh \
    ${systemd_system_unitdir}/edgeos-hostname.service \
    ${systemd_unitdir}/system-preset/90-edgeos.preset \
    "

RDEPENDS:${PN}-edgeos-hostname = "bash iproute2 systemd avahi-daemon"
SYSTEMD_SERVICE:${PN}-edgeos-hostname = "edgeos-hostname.service"
SYSTEMD_AUTO_ENABLE:${PN}-edgeos-hostname = "enable"

# Postinstall hook: safety net in case preset doesn't run at image build time
pkg_postinst:${PN}-edgeos-hostname () {
    if [ -z "$D" ]
    then
        systemctl enable edgeos-hostname.service || true
        systemctl start  edgeos-hostname.service || true
    fi
}
