# Enable PipeWire as a system service for headless operation
SYSTEMD_SERVICE:${PN} = "pipewire.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

SYSTEMD_SERVICE:pipewire-pulse = "pipewire-pulse.service"
SYSTEMD_AUTO_ENABLE:pipewire-pulse = "enable"

# Ensure Bluetooth support is enabled in PipeWire builds.
PACKAGECONFIG:append = " bluez bluez-opus"

# Ensure the service user has a writable home for WirePlumber state.
USERADD_PARAM:${PN} = "--system --home /var/lib/pipewire --create-home \
                       --comment 'PipeWire multimedia daemon' \
                       --gid pipewire --groups audio,video \
                       pipewire"
