#!/usr/bin/env bash

# auto-flash.sh - Automated Jetson flashing with initrd-flash
#
# Prerequisites:
#   - Jetson device accessible via SSH
#   - SSH key authentication configured for passwordless access (optional)
#       ssh-copy-id edge@<jetson-ip>
#   - tegra-rcm-trigger installed on Jetson device
#   - USB cable connected from Jetson recovery port to host PC
#

set -e

# Save original directory to restore on exit
ORIGINAL_DIR="$PWD"

# Variables for automount settings restoration
GNOME_MEDIA="org.gnome.desktop.media-handling"
AUTOMOUNT_ORIGINAL=""
AUTOMOUNT_OPEN_ORIGINAL=""

# Default configuration
# JETSON_IP="${JETSON_IP:-192.168.55.183}"
JETSON_IP="${JETSON_IP:-}"
JETSON_USER="${JETSON_USER:-edge}"
MACHINE_TYPE="nvme"
FLASH_DIR=""
SKIP_RECOVERY=false
ERASE_NVME=false
SKIP_CONFIRM=false
RECOVERY_TIMEOUT=60

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Disable automounting to prevent interference during flash
disable_automount() {
    if ! command -v gsettings >/dev/null 2>&1
    then
        return 0
    fi

    log_info "Checking automount settings..."
    AUTOMOUNT_ORIGINAL=$(gsettings get "${GNOME_MEDIA}" automount 2>/dev/null || echo "not-available")
    AUTOMOUNT_OPEN_ORIGINAL=$(gsettings get "${GNOME_MEDIA}" automount-open 2>/dev/null || echo "not-available")

    if [ "$AUTOMOUNT_ORIGINAL" != "not-available" ]
    then
        log_info "Disabling automount temporarily..."
        gsettings set "${GNOME_MEDIA}" automount false 2>/dev/null || true
        gsettings set "${GNOME_MEDIA}" automount-open false 2>/dev/null || true
    else
        log_warn "gsettings not available (non-GNOME system), skipping automount disable"
    fi

    echo ""
}

# Restore automount settings if they were changed
restore_automount() {
    if [ -n "$AUTOMOUNT_ORIGINAL" ] && [ "$AUTOMOUNT_ORIGINAL" != "not-available" ]
    then
        log_info "Restoring automount settings..."
        gsettings set "${GNOME_MEDIA}" automount "$AUTOMOUNT_ORIGINAL" 2>/dev/null || true
        gsettings set "${GNOME_MEDIA}" automount-open "$AUTOMOUNT_OPEN_ORIGINAL" 2>/dev/null || true
    fi
}

cleanup() {
    # Restore original directory
    if [ -n "$ORIGINAL_DIR" ] && [ -d "$ORIGINAL_DIR" ]
    then
        cd "$ORIGINAL_DIR" 2>/dev/null || true
    fi

    # Clear password from environment
    if [ -n "$SSHPASS" ]
    then
        unset SSHPASS
    fi

    # Restore automount settings if they were changed
    restore_automount
}

# Set up cleanup trap for all exit scenarios
#   - EXIT - Normal script exit
#   - INT - Ctrl-C (SIGINT)
#   - TERM - Termination signal (SIGTERM)
trap cleanup EXIT INT TERM

setup_ssh_auth() {
    # Try SSH key authentication first
    if ssh -o BatchMode=yes -o ConnectTimeout=3 "$JETSON_USER@$JETSON_IP" "exit" >/dev/null 2>&1
    then
        log_info "SSH key authentication detected"
        SSH_PREFIX=""
        return 0
    fi

    # SSH key auth failed, fall back to password authentication
    log_info "SSH key authentication not available, using password authentication"

    # Check if sshpass is installed
    if ! command -v sshpass >/dev/null 2>&1
    then
        log_error "sshpass is not installed!"
        log_info ""
        log_info "For password-based SSH authentication, install sshpass:"
        log_info "  sudo apt-get install sshpass"
        log_info ""
        log_info "Or set up SSH key authentication (recommended):"
        log_info "  ssh-copy-id $JETSON_USER@$JETSON_IP"
        return 1
    fi

    # Prompt for SSH password if not already set
    if [ -z "${SSHPASS}" ]
    then
        echo ""
        read -s -p "Enter SSH password for $JETSON_USER@$JETSON_IP: " SSHPASS
        echo ""
        export SSHPASS
    fi

    # Verify the password is correct
    if ! sshpass -e ssh -o BatchMode=no -o ConnectTimeout=5 "$JETSON_USER@$JETSON_IP" "exit" >/dev/null 2>&1
    then
        log_error "SSH authentication failed!"
        log_info "Please check:"
        log_info "  1. Password is correct"
        log_info "  2. Device is reachable at $JETSON_IP"
        log_info "  3. SSH service is running on the device"
        log_info "  4. User '$JETSON_USER' exists on the device"
        unset SSHPASS
        return 1
    fi

    log_info "Password authentication successful"
    SSH_PREFIX="sshpass -e"
    return 0
}

usage() {
    cat << EOF
Automated Jetson flashing with initrd-flash

Prerequisites:
  - Jetson device accessible via SSH
  - SSH key authentication configured for passwordless access (optional, if password is used):
      ssh-copy-id edge@<jetson-ip>
  - tegra-rcm-trigger installed on Jetson device
  - USB cable connected from Jetson recovery port to host PC

Usage: $0 [OPTIONS]

Options:
  -i, --ip=<ip>         Jetson IP address
  -u, --user=<user>     SSH user [default: ${JETSON_USER}]
  -m, --machine=<type>  Machine type: emmc or nvme [default: ${MACHINE_TYPE}]
  -d, --dir=<dir>       Flash directory (auto-detected if not specified)
  -s, --skip-recovery   Skip recovery trigger (device is already in recovery mode) [default: ${SKIP_RECOVERY}]
  -e, --erase           Erase NVMe before flashing [default: ${ERASE_NVME}]
  -y, --yes             Skip confirmation prompt [default: ${SKIP_CONFIRM}]
  -h, --help            Show this help

Examples:
  $0 -i <ip> -u edge -m nvme
  $0 --ip=<ip> --user=edge --machine=nvme
  $0 --ip=jetson.local --skip-recovery
  $0 -i <ip> -y  # Skip confirmation prompt
  $0 -d ./deploy/edgeos-image-jetson-orin-nano-devkit-nvme-edgeos

EOF
    exit 0
}

# Parse arguments (support both short and long options)
while [[ $# -gt 0 ]]
do
    case $1 in
        -i|--ip)
            JETSON_IP="$2"
            shift 2
            ;;
        --ip=*)
            JETSON_IP="${1#*=}"
            shift
            ;;
        -u|--user)
            JETSON_USER="$2"
            shift 2
            ;;
        --user=*)
            JETSON_USER="${1#*=}"
            shift
            ;;
        -m|--machine)
            MACHINE_TYPE="$2"
            shift 2
            ;;
        --machine=*)
            MACHINE_TYPE="${1#*=}"
            shift
            ;;
        -d|--dir)
            FLASH_DIR="$2"
            shift 2
            ;;
        --dir=*)
            FLASH_DIR="${1#*=}"
            shift
            ;;
        -s|--skip-recovery)
            SKIP_RECOVERY=true
            shift
            ;;
        -e|--erase)
            ERASE_NVME=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate prerequisites based on whether we're triggering recovery
if [ "$SKIP_RECOVERY" = false ]
then
    # Need IP address and SSH access to trigger recovery mode
    if [ -z "${JETSON_IP}" ]
    then
        log_error "Target IP address is required when triggering recovery mode!"
        log_info "Use --skip-recovery if device is already in recovery mode"
        usage
        exit 1
    fi

    # Setup SSH authentication method
    if ! setup_ssh_auth
    then
        log_error "Failed to setup SSH authentication"
        exit 1
    fi
else
    # Skip recovery mode - device should already be in recovery
    if [ -n "${JETSON_IP}" ]
    then
        log_warn "IP address provided but --skip-recovery is set (IP will be ignored)"
    fi
fi

# Auto-detect flash directory if not specified
if [ -z "$FLASH_DIR" ]
then
    # Look for directories containing initrd-flash script
    # Check common extraction locations
    SEARCH_PATHS=(
        "."
        "./deploy"
        "../deploy"
    )

    for search_path in "${SEARCH_PATHS[@]}"
    do
        if [ -f "$search_path/initrd-flash" ]
        then
            FLASH_DIR="$search_path"
            log_info "Auto-detected flash directory: $FLASH_DIR"
            break
        fi
    done

    if [ -z "$FLASH_DIR" ]
    then
        log_error "Flash directory not found. Please specify with --dir option"
        log_info ""
        log_info "The flash directory should contain the extracted tegraflash package"
        log_info "with initrd-flash script and all partition images."
        log_info ""
        log_info "Extract the tarball first:"
        log_info "  tar -xzf edgeos-image-*.tegraflash.tar.gz -C /path/to/dir"
        log_info "Then run:"
        log_info "  $0 --dir=/path/to/dir"
        exit 1
    fi
fi

# Verify flash directory exists and has required files
if [ ! -d "$FLASH_DIR" ]
then
    log_error "Flash directory not found: $FLASH_DIR"
    exit 1
fi

if [ ! -f "$FLASH_DIR/initrd-flash" ]
then
    log_error "initrd-flash script not found in $FLASH_DIR"
    log_info "Make sure you extracted the tegraflash tarball to this directory"
    exit 1
fi

log_info "Configuration:"
log_info "  Jetson IP:                    $JETSON_IP"
log_info "  SSH User:                     $JETSON_USER"
log_info "  Machine type:                 $MACHINE_TYPE"
log_info "  Flash folder:                 $FLASH_DIR"
log_info "  Skip recovery:                $SKIP_RECOVERY"
log_info "  Erase storage (NVMe/SD card): $ERASE_NVME"
echo ""

# Ask for confirmation unless skipped
if [ "$SKIP_CONFIRM" = false ]
then
    read -p "Continue with flashing? [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        log_info "Aborted by user"
        exit 0
    fi
    echo ""
fi

disable_automount

# Trigger recovery mode (unless skipped)
if [ "$SKIP_RECOVERY" = false ]
then
    log_info "Trigger reboot to recovery mode..."

    # Try tegra-rcm-trigger (verified working method for Jetson UEFI)
    # Use timeout to prevent hanging - SSH connection dies when device reboots
    # ServerAliveInterval/CountMax help detect when connection dies during reboot
    cmd="sudo tegra-rcm-trigger forced-recovery"
    opts=(-o ConnectTimeout=5 -o ServerAliveInterval=2 -o ServerAliveCountMax=3)
    timeout 5 $SSH_PREFIX ssh "${opts[@]}" "$JETSON_USER@$JETSON_IP" "${cmd}" || true

    log_info "Waiting for device to enter recovery mode..."
else
    log_info "Skip recovery mode trigger (assuming device is already in recovery)"
fi

# Wait for recovery mode
RECOVERY_DETECTED=false

for i in $(seq 1 $RECOVERY_TIMEOUT)
do
    if lsusb 2>/dev/null | grep -q "NVIDIA Corp.*APX"
    then
        log_info "Device in recovery mode detected!"
        RECOVERY_DETECTED=true
        break
    fi

    echo -n "."
    sleep 1
done

if [ "$RECOVERY_DETECTED" = false ]
then
    log_error "Device did not enter recovery mode after ${RECOVERY_TIMEOUT}s"
    log_info "Please check:"
    log_info "  1. USB cable is connected to recovery port"
    log_info "  2. Device is powered on"
    log_info "  3. lsusb shows something like 'NVIDIA Corp. APX'"
    exit 1
fi

# Show detected device info
lsusb | grep "NVIDIA Corp.*APX" | while read -r line
do
    log_info "Detected: '$line'"
done

# Flash the device
log_info "Flashing device..."
cd "$FLASH_DIR"

# Load board parameters from .env.initrd-flash
if [ ! -f ".env.initrd-flash" ]
then
    log_error ".env.initrd-flash not found in $FLASH_DIR"
    log_info "This file should be generated by the Yocto build and included in the flash package"
    exit 1
fi

# Source the environment file to load DEFAULTS array
log_info "Loading board parameters from .env.initrd-flash..."
declare -A DEFAULTS
source .env.initrd-flash

# Validate that DEFAULTS array is populated
if [ ${#DEFAULTS[@]} -eq 0 ]
then
    log_error "DEFAULTS array is empty in .env.initrd-flash"
    log_info "The file should contain board parameter definitions like:"
    log_info "  DEFAULTS[BOARDID]=\"3767\""
    log_info "  DEFAULTS[FAB]=\"RC1\""
    log_info "  etc."
    exit 1
fi

# Export all DEFAULTS entries as environment variables
# This makes the script future-proof if NVIDIA adds/removes parameters
log_info "Exporting board parameters:"
for key in "${!DEFAULTS[@]}"
do
    export "$key=${DEFAULTS[$key]}"
    log_info "  $key=${DEFAULTS[$key]}"
done
echo ""

# Detect USB instance using find-jetson-usb script
USB_INSTANCE=""
if [ -x "./find-jetson-usb" ]
then
    log_info "Detecting Jetson USB instance..."
    if ./find-jetson-usb >/dev/null 2>&1
    then
        if [ -f ".found-jetson" ]
        then
            # Read USB instance from .found-jetson file (format: usb_instance=1-2)
            # Extract just the value after '='
            USB_INSTANCE=$(grep "usb_instance=" .found-jetson | cut -d'=' -f2)
            log_info "Detected USB instance: $USB_INSTANCE"
        fi
    else
        log_warn "find-jetson-usb did not detect device (already detected earlier)"
    fi
fi

# Build flash command
FLASH_CMD="./initrd-flash"
if [ -n "$USB_INSTANCE" ]
then
    FLASH_CMD="$FLASH_CMD --usb-instance $USB_INSTANCE"
fi

if [ "$ERASE_NVME" = true ]
then
    FLASH_CMD="$FLASH_CMD --erase-nvme"
fi

log_info "Running: sudo $FLASH_CMD"
echo ""

if sudo -E $FLASH_CMD
then
    echo ""
    log_info "Flash completed successfully!"
    log_info "Device will reboot automatically"

    # Wait for device to come back online
    log_info "Waiting for device to boot (this may take 1-2 minutes)..."
    sleep 1

    for i in $(seq 1 120)
    do
        if ping -c 1 -W 1 "$JETSON_IP" >/dev/null 2>&1
        then
            log_info "Device is back online at $JETSON_IP"

            # Try to SSH and get some basic info
            sleep 5

            if $SSH_PREFIX ssh -o ConnectTimeout=5 "$JETSON_USER@$JETSON_IP" "echo 'SSH connection successful'" 2>/dev/null
            then
                log_info "SSH connection verified"
                log_info "Getting system info..."
                $SSH_PREFIX ssh "$JETSON_USER@$JETSON_IP" "uname -a && df -h | grep -E '(Filesystem|/dev/(mmcblk|nvme))'" || true
            fi
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""

else
    log_error "Flash failed! Check output above for errors"
    exit 1
fi

log_info "All done!"
