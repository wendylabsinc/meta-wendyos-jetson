#
# WendyOS Agent Download Script
# Downloads the wendy-agent binary from GitHub releases
#

set -e

# Load configuration
if [ -f /etc/default/wendy-agent ]; then
    source /etc/default/wendy-agent
fi

# Default values if not configured
GITHUB_REPO="${EDGE_AGENT_GITHUB_REPO:-wendylabsinc/wendy-agent}"
VERSION="${EDGE_AGENT_VERSION:-latest}"
ARCH="aarch64"  # Hardcoded for RPi

# Paths
INSTALL_DIR="/usr/local/bin"
BACKUP_DIR="/opt/wendy/bin"
BINARY_NAME="wendy-agent"
TEMP_DIR="/tmp/wendy-agent-download-$$"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    logger -t wendy-agent-download "$*"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

# Cleanup on exit
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# Check for required tools
check_requirements() {
    local missing_tools=()

    for tool in curl jq tar gzip; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=($tool)
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log "Installing missing tools: ${missing_tools[*]}"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y ${missing_tools[*]}
        elif command -v opkg >/dev/null 2>&1; then
            opkg update && opkg install ${missing_tools[*]}
        else
            error "Missing required tools: ${missing_tools[*]}"
        fi
    fi
}

# Get release information from GitHub - simplified version
get_release_info() {
    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases"

    log "Fetching releases from GitHub..." >&2

    # Use wget if available, otherwise curl
    local releases_json
    if command -v wget >/dev/null 2>&1; then
        releases_json=$(wget -q -O - "${api_url}" 2>/dev/null) || error "Failed to fetch releases"
    else
        releases_json=$(curl -sL "${api_url}" 2>/dev/null) || error "Failed to fetch releases"
    fi

    # Return the first release (latest pre-release or release)
    if command -v jq >/dev/null 2>&1; then
        echo "${releases_json}" | jq '.[0]' 2>/dev/null
    else
        # If jq is not available, return the raw JSON (first release)
        echo "${releases_json}"
    fi
}

# Download the binary - simplified version
download_binary() {
    local release_info="$1"

    # Create temp directory
    mkdir -p "${TEMP_DIR}"

    # Extract download URL for aarch64 binary
    local download_url

    if command -v jq >/dev/null 2>&1; then
        # Use jq if available - specifically look for wendy-agent (not wendy-cli)
        download_url=$(echo "${release_info}" | jq -r '.assets[]? | select(.name | contains("wendy-agent-linux-static-musl-aarch64")) | .browser_download_url' 2>/dev/null | head -1)
    else
        # Fallback to grep - look for the URL pattern
        download_url=$(echo "${release_info}" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*wendy-agent-linux-static-musl-aarch64[^"]*"' | head -1 | cut -d'"' -f4)
    fi

    if [ -z "${download_url}" ] || [ "${download_url}" = "null" ]; then
        error "No suitable binary found for architecture: ${ARCH} in ${release_info} ${download_url}"
    fi

    local filename="wendy-agent.tar.gz"
    log "Downloading: ${download_url}"

    # Use wget if available, otherwise curl
    if command -v wget >/dev/null 2>&1; then
        wget -O "${TEMP_DIR}/${filename}" "${download_url}" || error "Download failed"
    else
        curl -L -o "${TEMP_DIR}/${filename}" "${download_url}" || error "Download failed"
    fi

    # Extract the archive
    log "Extracting archive"
    tar -xzf "${TEMP_DIR}/${filename}" -C "${TEMP_DIR}"

    # Find the binary (exclude edge-cli)
    local binary_path
    binary_path=$(find "${TEMP_DIR}" -name "wendy-agent" -type f ! -path "*/wendy-cli*" | head -1)

    if [ -z "${binary_path}" ]; then
        error "Binary not found in archive"
    fi

    mv "${binary_path}" "${TEMP_DIR}/${BINARY_NAME}"
    chmod +x "${TEMP_DIR}/${BINARY_NAME}"

    log "Binary downloaded and prepared successfully"
}

# Install the binary
install_binary() {
    # Create directories if they don't exist
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "/var/lib/wendy-agent"

    log "Created required directories"

    # Backup existing binary if it exists
    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        log "Backing up existing binary"
        cp "${INSTALL_DIR}/${BINARY_NAME}" "${BACKUP_DIR}/${BINARY_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Install new binary
    log "Installing new binary to ${INSTALL_DIR}/${BINARY_NAME}"
    mv "${TEMP_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}.real"

    # If there's a placeholder script, replace it
    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ] && grep -q "Edge-agent not yet installed" "${INSTALL_DIR}/${BINARY_NAME}" 2>/dev/null; then
        mv "${INSTALL_DIR}/${BINARY_NAME}.real" "${INSTALL_DIR}/${BINARY_NAME}"
    else
        mv "${INSTALL_DIR}/${BINARY_NAME}.real" "${INSTALL_DIR}/${BINARY_NAME}"
    fi

    # Ensure proper permissions
    chmod 755 "${INSTALL_DIR}/${BINARY_NAME}"

    # Keep a backup copy
    cp "${INSTALL_DIR}/${BINARY_NAME}" "${BACKUP_DIR}/${BINARY_NAME}.latest"

    log "Edge-agent installed successfully"
}

# Main execution
main() {
    log "Starting wendy-agent download"
    log "Configuration: REPO=${GITHUB_REPO}, VERSION=${VERSION}, ARCH=${ARCH}"

    check_requirements

    local release_info
    release_info=$(get_release_info)

    download_binary "${release_info}"
    install_binary

    # Get version info if possible
    if "${INSTALL_DIR}/${BINARY_NAME}" --version >/dev/null 2>&1; then
        local installed_version=$("${INSTALL_DIR}/${BINARY_NAME}" --version 2>&1 | head -1)
        log "Installed version: ${installed_version}"
    fi

    log "Wendy-agent download completed successfully"
}

# Run main function
main "$@"
