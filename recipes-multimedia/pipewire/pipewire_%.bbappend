# Enable PipeWire as a system service for headless operation
SYSTEMD_SERVICE:${PN} = "pipewire.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
