#!/usr/bin/env bash
# Enable/disable/status internet sharing from host uplink to a Jetson USB gadget,
# when the Jetson is the DHCP server on the USB link.
#
# Usage:
#   sudo usb-internet-forward.sh enable  [USB_IFACE] [UPLINK_IFACE]
#   sudo usb-internet-forward.sh disable [USB_IFACE]
#   sudo usb-internet-forward.sh status  [USB_IFACE]
#
# If USB_IFACE is omitted, the script tries to auto-detect a likely USB NIC.
# If UPLINK_IFACE is omitted on 'enable', the default-route interface is used.

set -euo pipefail

ACTION="${1:-}"
USB_IFACE="${2:-}"
UPLINK_IFACE="${3:-}"

# if [ "$(id -u)" -ne 0 ]
# then
#     echo "This script must be run as root!" >&2
#     exit 1
# fi

required_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing dependency: $1" >&2
        exit 1
    }
}

required_cmd ip
required_cmd iptables
required_cmd sysctl

# STATE_DIR="/run/usb-fwd"
STATE_DIR="${HOME}/backups/usb-inet-share"
mkdir -p "${STATE_DIR}"

# iptables backup config
# BACKUP_DIR=${BACKUP_DIR:-/var/backups/usb-inet-share}
BACKUP_DIR=${BACKUP_DIR:-${STATE_DIR}}
mkdir -p "${BACKUP_DIR}"

backup_stamp() {
    date +%Y%m%d-%H%M%S
}

backup_prefix() {
    printf "%s/%s" "$BACKUP_DIR" "${1:-$(backup_stamp)}"
}

iptables_backup() {
    # $1 optional label (defaults to timestamp)
    local label="${1:-$(backup_stamp)}"
    local prefix; prefix="$(backup_prefix "$label")"
    local v4="${prefix}.v4"
    local v6="${prefix}.v6"

    # Save current rules (IPv4 + IPv6 if available)
    sudo iptables-save >"$v4"
    if command -v ip6tables-save >/dev/null 2>&1; then
        sudo ip6tables-save >"$v6"
    fi

    # Maintain a 'latest' pointer
    ln -sf "$(basename "$v4")"  "$BACKUP_DIR/latest.v4"
    [ -f "$v6" ] && ln -sf "$(basename "$v6")" "$BACKUP_DIR/latest.v6"

    echo "$v4"
}

iptables_restore() {
    # $1 optional label; if omitted, use latest
    local label="${1:-latest}"
    local v4 v6

    if [[ "$label" == "latest" ]]; then
        v4="$BACKUP_DIR/latest.v4"
        v6="$BACKUP_DIR/latest.v6"
        [[ -e "$v4" ]] || {
            echo "No latest backup found in $BACKUP_DIR" >&2
            return 1
        }
    else
        v4="$(backup_prefix "$label").v4"
        v6="$(backup_prefix "$label").v6"
        [[ -e "$v4" ]] || {
            echo "Backup '$label' not found in $BACKUP_DIR" >&2
            return 1
        }
    fi

    sudo iptables-restore <"$v4"
    if [[ -f "$v6" ]] && command -v ip6tables-restore >/dev/null 2>&1; then
        sudo ip6tables-restore <"$v6"
    fi
}

iptables_add() {
  local table="$1"

  shift
  sudo iptables -t "${table}" -C "$@" 2>/dev/null || sudo iptables -t "${table}" -A "$@"
}

iptables_remove() {
  local table="$1"

  shift
  sudo iptables -t "${table}" -C "$@" 2>/dev/null && sudo iptables -t "${table}" -D "$@"
}

autodetect_usb_iface() {
    # Prefer interfaces that look like USB NICs and are UP with a private IPv4
    # fallbacks: any non-default-route ethernet with carrier.
    local priv_pat='(^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.)'
    for iface in /sys/class/net/*
    do
        [ -e "${iface}" ] || continue          # skip if glob matches nothing
        iface=${iface##*/}                   # remove everything up to last /

        [[ "$iface" == "lo" ]] && continue

        # skip default route interface
        ip route show default | grep -qw " dev $iface " && continue

        # only consider ethernet-like
        [[ -e "/sys/class/net/$iface/type" ]] && [[ "$(cat /sys/class/net/$iface/type)" -ne 1 ]] && continue

        # link up?
        [[ -e "/sys/class/net/$iface/operstate" ]] && [[ "$(cat /sys/class/net/$iface/operstate)" != "up" ]] && continue

        # has private IPv4?
        if ip -4 addr show dev "$iface" | awk '/inet /{print $2}' | grep -Eq "$priv_pat"
        then
            echo "$iface"
            return
        fi
    done

    # last resort: first non-loopback ethernet without default route
    for iface in /sys/class/net/*
    do
        [ -e "${iface}" ] || continue          # skip if glob matches nothing
        iface=${iface##*/}                   # remove everything up to last /

        [[ "$iface" == "lo" ]] && continue

        ip route show default | grep -qw " dev $iface " && continue
        [[ -e "/sys/class/net/$iface/type" ]] && [[ "$(cat /sys/class/net/$iface/type)" -ne 1 ]] && continue

        echo "$iface"
        return
    done
}

autodetect_uplink_iface() {
    ip route show default | awk '/default/ {print $5; exit}'
}

state_file() {
    echo "${STATE_DIR}/fwd-${USB_IFACE}.env"
}

enable_forward() {
    [[ -n "${USB_IFACE:-}" ]] || USB_IFACE="$(autodetect_usb_iface || true)"
    [[ -n "${USB_IFACE:-}" ]] || {
        echo "Could not detect USB interface. Pass it explicitly." >&2
        exit 1
    }

    [[ -n "${UPLINK_IFACE:-}" ]] || UPLINK_IFACE="$(autodetect_uplink_iface || true)"
    [[ -n "${UPLINK_IFACE:-}" ]] || {
        echo "Could not detect uplink interface. Pass it explicitly." >&2
        exit
    }

    # Ensure usb interface is up (address comes from Jetson's DHCP)
    sudo ip link set "$USB_IFACE" up || true

    # Turn on IPv4 forwarding (runtime)
    sysctl -w net.ipv4.ip_forward=1 >/dev/null

    # NAT + forward rules
    iptables_add nat POSTROUTING -o "$UPLINK_IFACE" -j MASQUERADE
    iptables_add filter FORWARD -i "$UPLINK_IFACE" -o "$USB_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables_add filter FORWARD -i "$USB_IFACE" -o "$UPLINK_IFACE" -j ACCEPT

    # Save state for clean disable
    cat >"$(state_file)" <<EOF
USB_IFACE=${USB_IFACE}
UPLINK_IFACE=${UPLINK_IFACE}
EOF

    echo "✅ Internet sharing enabled"
    echo "   USB     : $USB_IFACE (gets IP from Jetson DHCP)"
    echo "   UPLINK  : $UPLINK_IFACE"
    ip -4 addr show dev "$USB_IFACE" | sed 's/^/   /'
}

disable_forward() {
    [[ -n "${USB_IFACE:-}" ]] || {
        echo "Specify USB_IFACE to disable, e.g. $0 disable usb0" >&2
        exit 1
    }

    # Load saved uplink if available
    if [[ -f "$(state_file)" ]]; then
        # shellcheck disable=SC1090
        . "$(state_file)"
    else
        : "${UPLINK_IFACE:=$(autodetect_uplink_iface || true)}"
    fi

    # Remove NAT/forward rules (ok if missing)
    [[ -n "${UPLINK_IFACE:-}" ]] && {
        iptables_remove nat POSTROUTING -o "$UPLINK_IFACE" -j MASQUERADE
        iptables_remove filter FORWARD -i "$UPLINK_IFACE" -o "$USB_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables_remove filter FORWARD -i "$USB_IFACE" -o "$UPLINK_IFACE" -j ACCEPT
    }

    rm -f "$(state_file)" || true

    # Optionally turn off ip_forward if no more states exist
    if ! ls "${STATE_DIR}"/fwd-*.env >/dev/null 2>&1; then
        sysctl -w net.ipv4.ip_forward=0 >/dev/null || true
    fi

    echo "🛑 Internet sharing disabled for $USB_IFACE"
}

status_forward() {
    [[ -n "${USB_IFACE:-}" ]] || USB_IFACE="$(autodetect_usb_iface || true)"
    if [[ -z "${USB_IFACE:-}" ]]; then
        echo "No candidate USB Gadget interface found!"
        exit 0
    fi

    echo "USB Gadget interface: $USB_IFACE"
    ip -4 addr show dev "$USB_IFACE" || true

    echo ""
    echo -n "ip_forward: "
    cat /proc/sys/net/ipv4/ip_forward || true

    echo "NAT rules:"
    sudo iptables -t nat -S POSTROUTING | sed 's/^/  /'
    echo ""

    echo "FORWARD rules:"
    sudo iptables -S FORWARD | sed 's/^/  /'
    echo ""

    [[ -f "$(state_file)" ]] && {
        echo "State:"
        cat "$(state_file)" | sed 's/^/  /'
    } || {
        echo "State: (none)"
    }

    echo ""
}

usage()
{
    PROG_NAME=$(basename $0)

    cat >&2 <<EOF

Manage internet sharing on the USB Gadget interface.
Usage:
    ${PROG_NAME} [<command>] [USB_IFACE] [UPLINK_IFACE]

Commands:
    status          Display the status of internet sharing
    enable          Enable internet sharing on USB Gadget
    disable         Disable internet sharing on USB Gadget
    backup          Save the current 'iptables' configuration
    restore         Restore the previously saved 'iptables' configuration

EOF
}

case "${ACTION:-}" in
    enable)  enable_forward ;;
    disable) disable_forward ;;
    status)  status_forward ;;
    backup) iptables_backup ;;
    restore) iptables_restore ;;
    *)
        # echo "Usage: sudo $0 {enable|disable|status} [USB_IFACE] [UPLINK_IFACE]"
        usage
        exit 2
        ;;
esac
