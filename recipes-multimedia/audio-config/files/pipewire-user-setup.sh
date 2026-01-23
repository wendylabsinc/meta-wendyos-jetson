#!/bin/bash
# pipewire-user-setup.sh
# Enables PipeWire and WirePlumber user services for the edge user
# Also ensures runtime directory exists for containers to access audio

set -e

USER="edge"
USER_HOME="/home/edge"
USER_UID=$(id -u "$USER" 2>/dev/null || echo "1000")
RUNTIME_DIR="/run/user/$USER_UID"

if [ ! -d "$USER_HOME" ]; then
    echo "User home directory $USER_HOME does not exist yet"
    exit 0
fi

echo "Setting up audio for user: $USER (UID: $USER_UID)"

# Enable user lingering (keeps user services running, creates /run/user/UID)
loginctl enable-linger "$USER" || true

# Give systemd time to create the runtime directory
sleep 2

# Ensure runtime directory exists and has correct permissions
if [ ! -d "$RUNTIME_DIR" ]; then
    echo "Creating runtime directory: $RUNTIME_DIR"
    mkdir -p "$RUNTIME_DIR"
    chown "$USER:$USER" "$RUNTIME_DIR"
    chmod 700 "$RUNTIME_DIR"
fi

# Enable and start user services as the edge user
su - "$USER" -c "
    export XDG_RUNTIME_DIR=$RUNTIME_DIR
    export DBUS_SESSION_BUS_ADDRESS=unix:path=\$XDG_RUNTIME_DIR/bus

    # Ensure runtime directory exists
    mkdir -p \$XDG_RUNTIME_DIR

    # Enable D-Bus user session
    systemctl --user enable dbus.service || true
    if ! systemctl --user is-active --quiet dbus.service; then
        systemctl --user start dbus.service || true
    fi

    # Wait for D-Bus to be ready
    sleep 1

    # Enable and start PipeWire socket (socket activation)
    systemctl --user enable pipewire.socket pipewire-pulse.socket || true
    systemctl --user start pipewire.socket pipewire-pulse.socket || true

    # Enable and start WirePlumber (PipeWire session manager)
    systemctl --user enable wireplumber.service || true
    systemctl --user start wireplumber.service || true

    # Wait for services to initialize
    sleep 2

    # Verify audio services are running
    echo '=== Audio Service Status ==='
    systemctl --user is-active pipewire.socket pipewire-pulse.socket wireplumber.service || true

    echo 'PipeWire audio services enabled for user: edge'
" || {
    echo "Failed to enable user services - will retry on next boot"
    exit 1
}

# Make runtime directory accessible to containers (readable for audio group)
# This allows containers running as different UIDs to access the sockets
chmod 755 "$RUNTIME_DIR" 2>/dev/null || true

echo "Audio setup complete for $USER"
exit 0
