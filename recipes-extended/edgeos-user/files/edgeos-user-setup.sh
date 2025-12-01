#!/bin/bash
# EdgeOS User Setup - First Boot Service
# This script runs once on first boot to initialize user home directories
# on the persistent data partition.

set -e

SETUP_FLAG="/data/.edgeos-user-setup-done"
DATA_HOME="/data/home"
EDGE_HOME="/data/home/edge"
EDGE_UID=1000
EDGE_GID=1000

# Check if already run
if [ -f "$SETUP_FLAG" ]; then
    echo "EdgeOS user setup already completed. Skipping."
    exit 0
fi

echo "Running EdgeOS user setup (first boot)..."

# Ensure /data is mounted
if ! mountpoint -q /data; then
    echo "ERROR: /data is not mounted. Cannot proceed."
    exit 1
fi

# Create /data/home if it doesn't exist
if [ ! -d "$DATA_HOME" ]; then
    echo "Creating $DATA_HOME..."
    mkdir -p "$DATA_HOME"
    chmod 0755 "$DATA_HOME"
fi

# Create edge user home directory if it doesn't exist
if [ ! -d "$EDGE_HOME" ]; then
    echo "Creating home directory for edge user at $EDGE_HOME..."
    mkdir -p "$EDGE_HOME"
    chmod 0755 "$EDGE_HOME"

    # Create .ssh directory
    mkdir -p "$EDGE_HOME/.ssh"
    chmod 0700 "$EDGE_HOME/.ssh"

    # Create minimal .bashrc that sources system profiles
    cat > "$EDGE_HOME/.bashrc" << 'EOF'
# EdgeOS User Environment
# System defaults are in /etc/profile.d/ and update via OTA
# Add your personal customizations below

# Source global profile if available
if [ -f /etc/profile ]; then
    . /etc/profile
fi

# User's personal customizations below this line
# These will persist across OTA updates

EOF
    chmod 0644 "$EDGE_HOME/.bashrc"

    # Create .profile for login shells
    cat > "$EDGE_HOME/.profile" << 'EOF'
# EdgeOS User Profile
# This file is sourced by login shells

# Source .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

EOF
    chmod 0644 "$EDGE_HOME/.profile"

    # Set ownership
    chown -R $EDGE_UID:$EDGE_GID "$EDGE_HOME"

    echo "Edge user home directory initialized at $EDGE_HOME"
else
    echo "Edge user home directory already exists at $EDGE_HOME"
fi

# Create flag file to indicate setup is complete
touch "$SETUP_FLAG"
echo "EdgeOS user setup complete."

exit 0
