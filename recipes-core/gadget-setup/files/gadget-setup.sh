#!/bin/sh

# Make the Jetson present itself as a USB NIC:
# - Prefer NCM (Linux/Win11/macOS new); fall back to ECM (macOS-friendly)
# - Give the host an automatic IP via dnsmasq (through a separate service)
#
set -eu

G=/sys/kernel/config/usb_gadget/g1
NET_IF=usb0
UDC=$(ls /sys/class/udc | head -n1 || true)

USB_VID=${USB_VID:-0x1d6b}          # Linux Foundation
USB_PID=${USB_PID:-0x0104}          # Multifunction composite
USB_SERIAL=${USB_SERIAL:-0123456789}
USB_MFR=${USB_MFR:-NVIDIA}
USB_PROD=${USB_PROD:-"edgeOS USB Network"}   # Shown on host as adapter description
CFG_NAME=${CFG_NAME:-"USB Networking"}
MAX_PWR=${MAX_PWR:-250}
GADGET_FUNC_ORDER="${GADGET_FUNC_ORDER:-ncm ecm}"

# Clean previous gadget if any
if [ -d "$G" ]; then
    echo "" > "$G/UDC" 2>/dev/null || true
    rm -rf "$G"
fi

# Mount configfs and load modules quietly
mountpoint -q /sys/kernel/config || mount -t configfs none /sys/kernel/config
depmod -a || true
modprobe -q libcomposite || true
modprobe -q u_ether || true
modprobe -q usb_f_ncm || true
modprobe -q usb_f_ecm || true

# Create gadget
mkdir -p "$G"
cd "$G"

echo "$USB_VID" > idVendor
echo "$USB_PID" > idProduct

mkdir -p strings/0x409
echo "$USB_SERIAL" > strings/0x409/serialnumber
echo "$USB_MFR"    > strings/0x409/manufacturer
echo "$USB_PROD"   > strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "$CFG_NAME" > configs/c.1/strings/0x409/configuration
echo "$MAX_PWR"  > configs/c.1/MaxPower

add_func() {
    case "$1" in
    ncm)
        mkdir -p functions/ncm.usb0 2>/dev/null || return 1
        ln -sf functions/ncm.usb0 configs/c.1/
        return 0
        ;;
    ecm)
        mkdir -p functions/ecm.usb0 2>/dev/null || return 1
        # Stable MACs help some hosts cache correctly
        echo 02:1A:11:00:00:01 > functions/ecm.usb0/dev_addr 2>/dev/null || true
        echo 02:1A:11:00:00:02 > functions/ecm.usb0/host_addr 2>/dev/null || true
        ln -sf functions/ecm.usb0 configs/c.1/
        return 0
        ;;
    esac
}

SEL=""
for f in $GADGET_FUNC_ORDER; do
    if add_func "$f"
    then
        SEL="$f"; break;
    fi
done

[ -n "$SEL" ] || {
    echo "ERROR: Neither NCM nor ECM is available"
    exit 1
}

# Bind to UDC
: "${UDC:=$(ls /sys/class/udc | head -n1 || true)}"
[ -n "$UDC" ] || {
    echo "ERROR: No UDC found"
    exit 2
}

echo "$UDC" > UDC

# USB gadget interface will be configured by NetworkManager
# NetworkManager will handle IP configuration and connection sharing
echo "Gadget ready: $SEL on $NET_IF, UDC=$UDC"
echo "NetworkManager will configure network settings"
