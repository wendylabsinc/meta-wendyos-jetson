# Enable PipeWire as a system service for headless operation
SYSTEMD_SERVICE:${PN} = "pipewire.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

SYSTEMD_SERVICE:pipewire-pulse = "pipewire-pulse.service"
SYSTEMD_AUTO_ENABLE:pipewire-pulse = "enable"
