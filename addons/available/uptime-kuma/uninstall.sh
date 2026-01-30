#!/bin/bash
set -euo pipefail

ADDON_NAME="uptime-kuma"
PURGE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --purge) PURGE=true; shift ;;
        *) echo "Ukendt argument: $1"; exit 1 ;;
    esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Stop og disable service
log "Stopper service..."
systemctl stop "$ADDON_NAME" 2>/dev/null || true
systemctl disable "$ADDON_NAME" 2>/dev/null || true

# Fjern systemd unit
log "Fjerner systemd service..."
rm -f "/etc/systemd/system/${ADDON_NAME}.service"
systemctl daemon-reload

# Fjern fra backup registration
log "Fjerner fra backup registrering..."
sed -i "\|/mnt/data/${ADDON_NAME}|d" /etc/humethix/backup-paths.conf 2>/dev/null || true

# Fjern fra tunnel registration
log "Fjerner fra tunnel registrering..."
sed -i "\|127.0.0.1:${PORT}|d" /etc/humethix/cloudflare-tunnels.conf 2>/dev/null || true

# Fjern container
log "Fjerner container..."
sudo -u "$ADDON_NAME" podman rm -f "$ADDON_NAME" 2>/dev/null || true
sudo -u "$ADDON_NAME" podman rmi -f "${IMAGE:-louislam/uptime-kuma}:${IMAGE_VERSION:-1}" 2>/dev/null || true

if [[ "$PURGE" == "true" ]]; then
    log "ADVARSEL: Sletter alle data for $ADDON_NAME"
    rm -rf "/mnt/data/${ADDON_NAME}"
    rm -rf "/etc/humethix/${ADDON_NAME}"
    rm -rf "/etc/humethix/secrets/${ADDON_NAME}"
    userdel -r "$ADDON_NAME" 2>/dev/null || true
else
    log "Data bevaret i /mnt/data/${ADDON_NAME}"
    log "Kør med --purge for at slette alt"
fi

log "=== $ADDON_NAME afinstalleret ==="
