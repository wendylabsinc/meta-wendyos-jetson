#!/bin/bash

# Setup bind mounts for persistent /etc files on /data partition
# This ensures device identity (UUID, hostname) persists across Mender OTA updates

set -e

DATA_ETC="/data/etc"
LOG_TAG="edgeos-etc-binds"
NM_CONNECTIONS="NetworkManager/system-connections"

log_info() {
    logger -t "${LOG_TAG}" -p user.info "$1"
    echo "[INFO] $1"
}

log_error() {
    logger -t "${LOG_TAG}" -p user.err "$1"
    echo "[ERROR] $1" >&2
}

# Verify /data is mounted
if ! mountpoint -q /data
then
    log_error "/data is not mounted, cannot setup bind mounts"
    exit 1
fi

log_info "Setting up persistent /etc bind mounts from /data"

# PHASE 1: identity files persistence (device-uuid, device-name)
log_info "Phase 1: Setting up identity files persistence"

# Create /data/etc/edgeos/ directory for identity files
if [ ! -d "${DATA_ETC}/edgeos" ]
then
    log_info "Creating ${DATA_ETC}/edgeos/ for persistent identity storage"
    mkdir -p "${DATA_ETC}/edgeos"
    chmod 755 "${DATA_ETC}/edgeos"
fi

# Bind-mount entire /etc/edgeos/ directory
# This persists device-uuid, device-name, and any other identity files
if ! mountpoint -q /etc/edgeos
then
    log_info "Bind-mounting ${DATA_ETC}/edgeos → /etc/edgeos"
    mount --bind "${DATA_ETC}/edgeos" /etc/edgeos

    if mountpoint -q /etc/edgeos
    then
        log_info "Successfully mounted /etc/edgeos"
    else
        log_error "Failed to bind-mount /etc/edgeos"
        exit 1
    fi
else
    log_info "/etc/edgeos already mounted, skipping"
fi

# [Note]
# /etc/hostname is NOT bind-mounted because file-level bind mounts prevent atomic
# writes. hostnamectl uses rename() for atomic updates, which fails with EBUSY on
# bind-mounted files. Instead, hostname is derived data that gets regenerated on
# every boot from the persistent device-name in /etc/edgeos/device-name.
# This approach matches industry patterns (Docker, CoreOS, Balena) where derived
# identities are computed from persisted seed data.
#

# PHASE 2:
log_info "Phase 2: Setting up NetworkManager user connections persistence"

# Create directory structure for NetworkManager connections
if [ ! -d "${DATA_ETC}/${NM_CONNECTIONS}" ]
then
    log_info "Creating ${DATA_ETC}/${NM_CONNECTIONS}/ for persistent WiFi configs"
    mkdir -p "${DATA_ETC}/${NM_CONNECTIONS}"
    chmod 755 "${DATA_ETC}/${NM_CONNECTIONS}"

    # Copy initial connection profiles from rootfs (e.g., usb-gadget.nmconnection)
    if [ -d "/etc/${NM_CONNECTIONS}" ]
    then
        # Check if there are any files to copy
        if ls "/etc/${NM_CONNECTIONS}"/*.nmconnection >/dev/null 2>&1
        then
            log_info "Copying initial NetworkManager connections from rootfs"
            cp -a "/etc/${NM_CONNECTIONS}"/*.nmconnection \
                "${DATA_ETC}/${NM_CONNECTIONS}/" 2>/dev/null || true

            # Ensure correct permissions (NetworkManager requires 0600)
            chmod 600 "${DATA_ETC}/${NM_CONNECTIONS}"/*.nmconnection 2>/dev/null || true
        else
            log_info "No initial connection profiles found in rootfs"
        fi
    fi
fi

# Bind-mount NetworkManager system-connections directory
# This allows user-configured WiFi/VPN connections to persist across OTA updates
if ! mountpoint -q "/etc/${NM_CONNECTIONS}"
then
    log_info "Bind-mounting ${DATA_ETC}/${NM_CONNECTIONS} → /etc/${NM_CONNECTIONS}"
    mount --bind "${DATA_ETC}/${NM_CONNECTIONS}" "/etc/${NM_CONNECTIONS}"

    if mountpoint -q "/etc/${NM_CONNECTIONS}"
    then
        log_info "Successfully mounted /etc/${NM_CONNECTIONS}"
    else
        log_error "Failed to bind-mount /etc/${NM_CONNECTIONS}"
        exit 1
    fi
else
    log_info "/etc/${NM_CONNECTIONS} already mounted, skipping"
fi

# Verification...
log_info "Verifying all bind mounts are active"

MOUNT_CHECKS=(
    "/etc/edgeos"
    "/etc/${NM_CONNECTIONS}"
)

FAILED=0
for mount_point in "${MOUNT_CHECKS[@]}"
do
    if mountpoint -q "${mount_point}"
    then
        log_info "✓ ${mount_point} is mounted"
    else
        log_error "✗ ${mount_point} is NOT mounted"
        FAILED=1
    fi
done

if [ ${FAILED} -eq 0 ]
then
    log_info "All bind mounts successfully configured"
    exit 0
else
    log_error "Some bind mounts failed, check logs"
    exit 1
fi
