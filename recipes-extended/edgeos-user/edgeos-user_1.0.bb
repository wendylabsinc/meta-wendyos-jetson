SUMMARY = "EdgeOS Default User Configuration"
DESCRIPTION = "Creates the default 'edge' user with appropriate permissions for EdgeOS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit useradd

# Create edge user - simplified group list (non-existent groups cause failures)
USERADD_PACKAGES = "${PN}"
# Password 'edge' hash generated with: openssl passwd -6 -salt 5ixFr0sKRtsKKKhY edge
USERADD_PARAM:${PN} = "-m -d /home/edge -s /bin/bash -G dialout,video,audio,users -p '\$6\$5ixFr0sKRtsKKKhY\$NBU4Np0LBKjFMFZ5BpJr8wLT5UvTpY1cVFGdUWMCs0m4UDGMTHlU2efR6Qfwq5BMtCq8wqN.RoZH/vEt/cuyE1' edge"

do_install() {
    # Create home directory structure
    install -d -m 0755 ${D}/home/edge
    install -d -m 0700 ${D}/home/edge/.ssh
    
    # Create default .bashrc
    cat > ${D}/home/edge/.bashrc << 'EOF'
# EdgeOS user environment
export PS1='\u@\h:\w\$ '
export PATH=$PATH:/usr/local/bin:/usr/sbin:/sbin

# Aliases
alias ll='ls -la'
alias l='ls -CF'

# EdgeOS specific
if [ -f /etc/edgeos-build-id ]; then
    export EDGEOS_BUILD=$(cat /etc/edgeos-build-id)
fi

if [ -f /etc/edgeos/device-uuid ]; then
    export EDGEOS_UUID=$(cat /etc/edgeos/device-uuid)
fi
EOF
    
    # Set proper ownership
    chown -R 1000:1000 ${D}/home/edge
}

pkg_postinst_ontarget:${PN}() {
    # Add sudoers entry for edge user on target only
    if [ -d /etc/sudoers.d ]; then
        echo "edge ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/edge
        chmod 0440 /etc/sudoers.d/edge
    fi
}

FILES:${PN} += "/home/edge"

# Ensure sudo is available
RDEPENDS:${PN} = "sudo bash"