# Fix mender-resize-data-part substitution for NVMe devices
# The upstream recipe doesn't properly substitute MENDER_DATA_PART for NVMe configs

do_install:prepend:class-target:mender-growfs-data:mender-systemd() {
    # Force the substitution to use the correct MENDER_DATA_PART value
    sed -i "s#@MENDER_DATA_PART@#${MENDER_DATA_PART}#g" \
        ${WORKDIR}/mender-resize-data-part.sh.in

    sed -i "s#@MENDER_DATA_PART_NUMBER@#${MENDER_DATA_PART_NUMBER}#g" \
        ${WORKDIR}/mender-resize-data-part.sh.in
}
