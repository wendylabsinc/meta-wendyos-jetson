 #!/usr/bin/env sh

set -e

CAPTARGET="/boot/efi/EFI/UpdateCapsule/TEGRA_BL.Cap"
OSIND_FILE="/sys/firmware/efi/efivars/OsIndications-8be4df61-93ca-11d2-aa0d-00e098032b8c"

# Remove capsule file
if [ -f "${CAPTARGET}" ]
then
    rm "${CAPTARGET}"
fi

# Clear OSIndications variable
if [ -w "${OSIND_FILE}" ]
then
    # Write: 4-byte attributes (0x00000007) + 8-byte zero value
    # printf '\x07\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "${OSIND_FILE}"

    # Clear OSIndications (set all bytes to 0x00)
    # Format: 4-byte attributes (0x07000000) + 8-byte UINT64 value (0x0000000000000000)
    echo -ne '\x07\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' | sudo tee ${OSIND_FILE} > /dev/null
fi
