#!/bin/bash
#
# EdgeOS Hostname Generation Script
# Generates a unique hostname based on device UUID (fallback to serial/MAC)
#

set -Eeuo pipefail

UUID_FILE="/etc/edgeos/device-uuid"
PREFIX="edgeos"
STATE_DIR="/etc/edgeos"
STATE_HOSTNAME_FILE="${STATE_DIR}/hostname"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    logger -t edgeos-hostname "$*" || true
}

# Validate UUID (accepts with/without dashes, case-insensitive)
is_valid_uuid() {
    local v="${1,,}"
    [[ "$v" =~ ^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$ ]]
}

# Primary source: device UUID
get_device_uuid() {
    local uuid=""
    if [ -r "$UUID_FILE" ]; then
        uuid="$(tr -d '[:space:]' < "$UUID_FILE" 2>/dev/null || true)"
    fi
    echo "$uuid"
}

# Fallback legacy ID (serial/MAC/machine-id) – used only if UUID is missing/invalid
get_legacy_id() {
    local device_id=""
    # Raspberry Pi serial
    if [ -f /proc/cpuinfo ]; then
        device_id=$(grep -m1 '^Serial' /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | tr -d ' ' || true)
    fi
    # machine-id (partial)
    if [ -z "${device_id}" ] && [ -f /etc/machine-id ]; then
        device_id=$(head -c 16 /etc/machine-id || true)
    fi
    # first MAC
    if [ -z "${device_id}" ]; then
        device_id=$(ip link show | awk '/ether/ {gsub(":","",$2); print $2; exit}')
    fi
    # random fallback
    if [ -z "${device_id}" ]; then
        device_id=$(tr -dc 'a-f0-9' < /dev/urandom | head -c 16)
    fi
    echo "$device_id"
}

# Generate hostname from UUID (preferred) or legacy ID (fallback)
generate_hostname() {
    local uuid short_id legacy
    uuid="$(get_device_uuid)"

    if [ -n "$uuid" ] && is_valid_uuid "$uuid"; then
        uuid="${uuid//-/}"
        uuid="${uuid,,}"
        short_id="${uuid: -8}"
    else
        legacy="$(get_legacy_id)"
        legacy="${legacy//-/}"
        legacy="${legacy,,}"
        short_id="${legacy: -8}"
    fi

    echo "${PREFIX}-${short_id}"
}

# Set hostname
set_hostname() {
    local new_hostname="$1"
    local current_hostname
    current_hostname=$(hostname || echo "")

    if [ "${current_hostname}" = "${new_hostname}" ]; then
        log "Hostname already set to ${new_hostname}"
        return 0
    fi

    log "Setting hostname to ${new_hostname}"

    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "${new_hostname}"
        echo "${new_hostname}" > /etc/hostname   # menține sincron/compat
    else
        echo "${new_hostname}" > /etc/hostname
        hostname "${new_hostname}"
    fi

    # Update /etc/hosts (idempotent)
    if [ -f /etc/hosts ]; then
        grep -q "${new_hostname}" /etc/hosts 2>/dev/null || {
            sed -i '/edgeos-/d' /etc/hosts 2>/dev/null || true
            echo "127.0.1.1 ${new_hostname} ${new_hostname}.local" >> /etc/hosts
        }
    else
        echo "127.0.1.1 ${new_hostname} ${new_hostname}.local" > /etc/hosts
    fi

    log "Hostname set successfully to ${new_hostname}"
}

main() {
    log "Starting EdgeOS hostname generation"

    # Allow opt-out
    if [ -f /etc/edgeos-hostname-override ]; then
        log "Hostname override found, skipping automatic generation"
        exit 0
    fi

    mkdir -p "${STATE_DIR}"

    local new
    new="$(generate_hostname)"
    set_hostname "${new}"

    echo "${new}" > "${STATE_HOSTNAME_FILE}"

    # Restart avahi-daemon to broadcast the new name via mDNS (if present)
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet avahi-daemon.service; then
        log "Restarting avahi-daemon to pick up new hostname"
        systemctl restart avahi-daemon.service || true
    fi

    log "EdgeOS hostname generation completed: ${new}"
}

main "$@"
