SUMMARY = "EdgeOS Audio and Bluetooth support"
DESCRIPTION = "PipeWire, PulseAudio compatibility, and BlueZ for audio and Bluetooth"
LICENSE = "MIT"

PR = "r0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

# PipeWire - modern audio/video server (replaces PulseAudio)
RDEPENDS:${PN} = " \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-spa-plugins-meta \
    wireplumber \
    "

# BlueZ - Bluetooth stack
RDEPENDS:${PN}:append = " \
    bluez5 \
    bluez5-obex \
    "

# ALSA utilities
RDEPENDS:${PN}:append = " \
    alsa-utils \
    "
