#!/bin/sh
# Set default route via the host connected on usb0, based on dnsmasq leases.

LEASE_FILE=${LEASE_FILE:-/var/lib/misc/dnsmasq.leases}
DEV=${DEV:-usb0}

log() { logger -t usb0-route "$*"; }

# Need usb0 IPv4 first
ADDR_CIDR="$(ip -4 -o addr show dev "$DEV" 2>/dev/null | awk '{print $4}' | head -n1)"
[ -z "$ADDR_CIDR" ] && { log "no IPv4 on $DEV, skipping"; exit 0; }

SELF_IP="${ADDR_CIDR%/*}"
SUBNET_PREFIX="$(printf '%s.' "$(echo "$SELF_IP" | awk -F. '{print $1"."$2"."$3}')")"

# Find the latest lease in the same /24 (not ourselves)
if [ -r "$LEASE_FILE" ]; then
    HOST_IP="$(awk -v sub="$SUBNET_PREFIX" -v self="$SELF_IP" '
        $3 ~ "^"sub && $3 != self {ip=$3} END{print ip}' "$LEASE_FILE")"
fi

if [ -z "$HOST_IP" ]; then
    # Try neighbor table as a fallback (after some traffic)
    HOST_IP="$(ip neigh show dev "$DEV" nud reachable nud stale nud delay nud probe \
               | awk "{print \$1}" | grep -E "^${SUBNET_PREFIX}[0-9]+$" | head -n1)"
fi

if [ -n "$HOST_IP" ]; then
    ip route replace default via "$HOST_IP" dev "$DEV"
    rc=$?
    log "default route via $HOST_IP on $DEV (rc=$rc)"
    exit 0
else
    log "no suitable host IP found on $DEV; will retry on next lease change"
    exit 0
fi

