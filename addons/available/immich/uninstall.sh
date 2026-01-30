#!/bin/bash
set -euo pipefail

ADDON_NAME="immich"
PURGE=false

# Storage paths
STORAGE_MOUNT="/mnt/immich-storage"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --purge) PURGE=true; shift ;;
        *) echo "Ukendt argument: $1"; exit 1 ;;
    esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ADVARSEL: $*"; }

# Stop og disable service
log "Stopper Immich service..."
systemctl stop "$ADDON_NAME" 2>/dev/null || true
systemctl disable "$ADDON_NAME" 2>/dev/null || true

# Fjern systemd unit
log "Fjerner systemd service..."
rm -f "/etc/systemd/system/${ADDON_NAME}.service"
systemctl daemon-reload

# Stop containers
log "Stopper containers..."
if [[ -f "/etc/humethix/${ADDON_NAME}/docker-compose.yml" ]]; then
    sudo -u "$ADDON_NAME" podman-compose -f "/etc/humethix/${ADDON_NAME}/docker-compose.yml" down 2>/dev/null || true
fi

# Fjern containers
log "Fjerner containers..."
sudo -u "$ADDON_NAME" podman rm -f immich_server 2>/dev/null || true
sudo -u "$ADDON_NAME" podman rm -f immich_machine_learning 2>/dev/null || true
sudo -u "$ADDON_NAME" podman rm -f immich_redis 2>/dev/null || true
sudo -u "$ADDON_NAME" podman rm -f immich_postgres 2>/dev/null || true

# Fjern images
log "Fjerner images..."
sudo -u "$ADDON_NAME" podman rmi -f "ghcr.io/immich-app/immich-server:${IMAGE_VERSION:-v1.106.0}" 2>/dev/null || true
sudo -u "$ADDON_NAME" podman rmi -f "ghcr.io/immich-app/immich-machine-learning:${IMAGE_VERSION:-v1.106.0}" 2>/dev/null || true
sudo -u "$ADDON_NAME" podman rmi -f "redis:7-alpine" 2>/dev/null || true
sudo -u "$ADDON_NAME" podman rmi -f "postgres:14-alpine" 2>/dev/null || true

# Fjern fra backup registration
log "Fjerner fra backup registrering..."
sed -i "\|${STORAGE_MOUNT}|d" /etc/humethix/backup-paths.conf 2>/dev/null || true
sed -i "\|/mnt/data/${ADDON_NAME}|d" /etc/humethix/backup-paths.conf 2>/dev/null || true

# Fjern fra tunnel registration
log "Fjerner fra tunnel registrering..."
sed -i "\|127.0.0.1:${WEB_PORT:-2283}|d" /etc/humethix/cloudflare-tunnels.conf 2>/dev/null || true

if [[ "$PURGE" == "true" ]]; then
    warn "ADVARSEL: Dette vil slette ALLE Immich data inklusiv billeder!"
    warn "Storage device vil IKKE blive formateret, men data vil blive slettet."
    read -p "Er du sikker? [skriv 'JA' for at bekræfte]: " -r
    echo
    if [[ ! $REPLY == "JA" ]]; then
        log "Afinstallation afbrudt - data bevaret"
        exit 0
    fi
    
    log "Sletter Immich data..."
    
    # Slet data mapper
    rm -rf "/mnt/data/${ADDON_NAME}"
    rm -rf "/etc/humethix/${ADDON_NAME}"
    rm -rf "/etc/humethix/secrets/${ADDON_NAME}"
    
    # Slet storage data (men behold mount)
    if [[ -d "$STORAGE_MOUNT" ]]; then
        rm -rf "${STORAGE_MOUNT}/library" 2>/dev/null || true
        rm -rf "${STORAGE_MOUNT}/uploads" 2>/dev/null || true
        rm -rf "${STORAGE_MOUNT}/thumbnails" 2>/dev/null || true
        rm -rf "${STORAGE_MOUNT}/profile" 2>/dev/null || true
        warn "Storage data slettet fra $STORAGE_MOUNT"
        warn "Mount point og filesystem er bevaret"
    fi
    
    # Fjern user
    userdel -r "$ADDON_NAME" 2>/dev/null || true
    
    # Fjern fstab entry (valgfrit - spørg bruger)
    if findmnt -rn "$STORAGE_MOUNT" &>/dev/null; then
        warn "Storage device er stadig mountet på $STORAGE_MOUNT"
        warn "Vil du fjerne fstab entry og unmount?"
        read -p "Fjern fstab entry? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Find og fjern fstab entry
            local uuid=$(findmnt -rn -o UUID "$STORAGE_MOUNT" 2>/dev/null || echo "")
            if [[ -n "$uuid" ]]; then
                sed -i "\|$uuid|d" /etc/fstab
            fi
            umount "$STORAGE_MOUNT" 2>/dev/null || true
            log "Storage device unmountet og fstab entry fjernet"
        fi
    fi
else
    log "Data bevaret:"
    log "  Storage: $STORAGE_MOUNT"
    log "  Config: /mnt/data/${ADDON_NAME}"
    log "  Secrets: /etc/humethix/secrets/${ADDON_NAME}"
    log "Kør med --purge for at slette alt data"
fi

log "=== $ADDON_NAME afinstalleret ==="
