# Enable DBus support for NetworkManager integration
# NetworkManager's connection sharing (ipv4.method=shared) requires
# dnsmasq with DBus support to provide DHCP service

PACKAGECONFIG:append = " dbus"

# Disable the system-wide dnsmasq.service
# NetworkManager will spawn its own dnsmasq instances as needed
SYSTEMD_AUTO_ENABLE = "disable"
