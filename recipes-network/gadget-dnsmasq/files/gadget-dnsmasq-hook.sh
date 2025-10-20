#!/usr/bin/env bash

# dnsmasq lease hook: $1=add|old|del, $2=MAC, $3=IP, $4=HOSTNAME
# Environment: DNSMASQ_INTERFACE

set -euo pipefail

ACTION="${1:-}"; MAC="${2:-}"; IP="${3:-}"; IFACE="${DNSMASQ_INTERFACE:-}"
TARGET_IF="usb0"

log(){ logger -t gadget-dnsmasq-hook "$*"; }

[ "${IFACE}" = "${TARGET_IF}" ] || exit 0

case "${ACTION}" in
  add|old)
    if [ -n "${IP}" ]; then
      ip link set "${TARGET_IF}" up || true
      ip route replace default via "${IP}" dev "${TARGET_IF}" metric 50 || true
      log "default route set via ${IP} on ${TARGET_IF} (${ACTION})"
    fi
    ;;
  del)
    ip route | awk -v if="${TARGET_IF}" '$1=="default" && $0 ~ (" dev "if" ")' | while read -r _; do
      ip route del default dev "${TARGET_IF}" 2>/dev/null || true
      log "default route removed on ${TARGET_IF}"
    done
    ;;
esac
