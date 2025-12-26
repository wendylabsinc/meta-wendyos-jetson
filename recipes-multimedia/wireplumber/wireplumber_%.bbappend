# Enable WirePlumber as a system service for headless operation
SYSTEMD_SERVICE:${PN} = "wireplumber.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
