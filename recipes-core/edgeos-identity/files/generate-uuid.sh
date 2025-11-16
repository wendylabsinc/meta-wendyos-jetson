#!/bin/bash
# EdgeOS Device UUID Generation Script
# Generates a unique device UUID on first boot

UUID_FILE="/etc/edgeos/device-uuid"
UUID_DIR=$(dirname "$UUID_FILE")

# Check if UUID already exists
if [ -f "$UUID_FILE" ]; then
    echo "Device UUID already exists: $(cat $UUID_FILE)"
    exit 0
fi

# Create directory if it doesn't exist
if [ ! -d "$UUID_DIR" ]; then
    mkdir -p "$UUID_DIR"
    chmod 755 "$UUID_DIR"
fi

# Generate new UUID
NEW_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# Write UUID to file
echo "$NEW_UUID" > "$UUID_FILE"
chmod 644 "$UUID_FILE"

echo "Generated new device UUID: $NEW_UUID"

# Also write to kernel log for debugging
logger -t edgeos-identity "Generated device UUID: $NEW_UUID"