
# Image outputs: disk + OTA artifact
# IMAGE_FSTYPES += "uefiimg mender ext4"

INHERIT += "mender-full"

# tegra
# these two classes only work as intended when being inherited in the
# OE4t setup-env.sh style environment, as they modify bblayers.conf
# and expect additional information on the host.
INHERIT:remove = "tegra-support-sanity distro_layer_buildinfo"
INHERIT += "tegra-mender-setup"
