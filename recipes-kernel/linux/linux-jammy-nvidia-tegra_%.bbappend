
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += " \
    file://usb-gadget.cfg \
    file://reboot-mode.cfg \
    "

# file://enable_efi_stub.cfg
