#!/bin/sh

# USB Gadget Setup for WendyOS
# Configures NCM (Network Control Model) USB gadget with optimized settings
# Compatible with Linux, Windows 11, and macOS
#
set -eu

G=/sys/kernel/config/usb_gadget/wendyos_device
NET_IF=usb0
UDC=$(ls /sys/class/udc | head -n1 || true)

# USB Device Identification
USB_VID=${USB_VID:-0x1d6b}           # Linux Foundation
USB_PID=${USB_PID:-0x0104}           # Multifunction Composite Gadget
USB_MFR=${USB_MFR:-"Wendy Labs Inc"}
CFG_NAME=${CFG_NAME:-"NCM Network"}
MAX_PWR=${MAX_PWR:-250}
GADGET_FUNC_ORDER="${GADGET_FUNC_ORDER:-ncm ecm}"

# Get device serial number
DEVICE_SERIAL=""
if [ -f /proc/device-tree/serial-number ]; then
    DEVICE_SERIAL=$(cat /proc/device-tree/serial-number 2>/dev/null | tr -d '\0')
fi
if [ -z "$DEVICE_SERIAL" ]; then
    DEVICE_SERIAL=$(cat /sys/devices/platform/tegra-fuse/uid 2>/dev/null || echo "")
fi
if [ -z "$DEVICE_SERIAL" ]; then
    DEVICE_SERIAL=$(cat /sys/class/net/eth0/address 2>/dev/null | tr -d ':' || date +%s)
fi
USB_SERIAL=${USB_SERIAL:-$DEVICE_SERIAL}

# Get friendly device name if available
if [ -f /etc/wendyos/device-name ]; then
    DEVICE_NAME=$(cat /etc/wendyos/device-name | tr -d '[:space:]')
    USB_PROD=${USB_PROD:-"WendyOS Device ${DEVICE_NAME}"}
else
    SHORT_SERIAL=${DEVICE_SERIAL: -8}
    USB_PROD=${USB_PROD:-"WendyOS Device ${SHORT_SERIAL}"}
fi

# Generate MAC address from input string (locally administered)
generate_mac() {
    local input="$1"
    local hash=$(echo -n "$input" | md5sum | awk '{print $1}')
    local mac_base=${hash:0:12}
    local first_byte=${mac_base:0:2}
    local second_char=$(printf '%x' $((0x$first_byte & 0xfe | 0x02)))
    printf "%02x:%02x:%02x:%02x:%02x:%02x" \
       0x$second_char \
       0x${mac_base:2:2} \
       0x${mac_base:4:2} \
       0x${mac_base:6:2} \
       0x${mac_base:8:2} \
       0x${mac_base:10:2}
}

# Generate stable MAC addresses from device serial
MAC_HOST=$(generate_mac "${DEVICE_SERIAL}-host")
MAC_DEV=$(generate_mac "${DEVICE_SERIAL}-dev")

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

# Detect USB controller and set USB version
# Jetson Orin uses 3550000.usb (tegra-xudc), check via symlink target path
USB_VERSION="0x0200"  # Default USB 2.0
UDC_LINK=$(ls -la /sys/class/udc/ 2>/dev/null | head -2 | tail -1)
if echo "$UDC_LINK" | grep -qE "dwc3|tegra|3550000"; then
    USB_VERSION="0x0320"  # USB 3.2
    echo "Detected USB 3.x capable controller - enabling USB 3.2 mode"
fi
echo "$USB_VERSION" > bcdUSB
echo "0x0100" > bcdDevice

# Device class for composite device (IAD)
echo 0xEF > bDeviceClass      # Miscellaneous
echo 0x02 > bDeviceSubClass   # Common Class
echo 0x01 > bDeviceProtocol   # Interface Association Descriptor

mkdir -p strings/0x409
echo "$USB_SERIAL" > strings/0x409/serialnumber
echo "$USB_MFR"    > strings/0x409/manufacturer
echo "$USB_PROD"   > strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "$CFG_NAME" > configs/c.1/strings/0x409/configuration
echo "$MAX_PWR"  > configs/c.1/MaxPower
echo 0xC0 > configs/c.1/bmAttributes  # Self-powered

add_func() {
    case "$1" in
    ncm)
        mkdir -p functions/ncm.usb0 2>/dev/null || return 1
        echo "$MAC_HOST" > functions/ncm.usb0/host_addr 2>/dev/null || true
        echo "$MAC_DEV" > functions/ncm.usb0/dev_addr 2>/dev/null || true
        # Performance tuning: increase queue multiplier (default 5, use 10 for ~2x throughput)
        echo 10 > functions/ncm.usb0/qmult 2>/dev/null || true
        ln -sf functions/ncm.usb0 configs/c.1/
        return 0
        ;;
    ecm)
        mkdir -p functions/ecm.usb0 2>/dev/null || return 1
        echo "$MAC_HOST" > functions/ecm.usb0/host_addr 2>/dev/null || true
        echo "$MAC_DEV" > functions/ecm.usb0/dev_addr 2>/dev/null || true
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

# Wait for interface to appear
sleep 1

# Apply network interface performance tuning
if ip link show "$NET_IF" >/dev/null 2>&1; then
    # Set TX queue length for better burst handling (default ~1000, use 2000)
    ip link set "$NET_IF" txqueuelen 2000 2>/dev/null || true
fi

# Optimize USB IRQ affinity for Jetson (pin to CPUs 0-3)
USB_IRQ=$(grep -E "3550000\.usb|tegra-xudc" /proc/interrupts 2>/dev/null | cut -d: -f1 | tr -d ' ' | head -1)
if [ -n "$USB_IRQ" ]; then
    echo "0f" > /proc/irq/$USB_IRQ/smp_affinity 2>/dev/null || true
fi

echo "Gadget ready: $SEL on $NET_IF, UDC=$UDC, USB=$USB_VERSION"
echo "USB Product: $USB_PROD"
echo "NetworkManager will configure network settings"
