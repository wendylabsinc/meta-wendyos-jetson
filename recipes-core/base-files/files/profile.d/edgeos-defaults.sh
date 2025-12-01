#!/bin/sh
# EdgeOS System Defaults - Updated via OTA
# This file is part of the rootfs and will be updated with each OTA update
# User customizations should go in ~/.bashrc or ~/.profile

# Set prompt
export PS1='\u@\h:\w\$ '

# Extend PATH with common directories
export PATH=$PATH:/usr/local/bin:/usr/sbin:/sbin

# EdgeOS build information
if [ -f /etc/edgeos-build-id ]; then
    export EDGEOS_BUILD=$(cat /etc/edgeos-build-id)
fi

# EdgeOS device UUID
if [ -f /etc/edgeos/device-uuid ]; then
    export EDGEOS_UUID=$(cat /etc/edgeos/device-uuid)
fi

# Useful aliases
alias ll='ls -la'
alias l='ls -CF'
alias la='ls -A'

# EdgeOS specific commands
alias edgeos-version='cat /etc/edgeos-build-id 2>/dev/null || echo "Build ID not available"'
alias edgeos-uuid='cat /etc/edgeos/device-uuid 2>/dev/null || echo "UUID not available"'

# Mender commands (if mender is installed)
if command -v mender >/dev/null 2>&1; then
    alias mender-status='mender show-artifact'
    alias mender-check='mender check-update'
fi
