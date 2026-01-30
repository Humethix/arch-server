#!/bin/bash
set -euo pipefail

# =============================================================================
# Uptime Kuma Installation Script
# Humethix Addon System v1.0
# =============================================================================

ADDON_NAME="uptime-kuma"
ADDON_VERSION="1.0.0"

# Paths
DATA_DIR="/mnt/data/${ADDON_NAME}"
CONFIG_DIR="/etc/humethix/${ADDON_NAME}"
SECRETS_DIR="/etc/humethix/secrets/${ADDON_NAME}"
SERVICE_USER="${ADDON_NAME}"

# -----------------------------------------------------------------------------
# Load configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    source "${SCRIPT_DIR}/config.env"
else
    echo "FEJL: config.env ikke fundet. Kopiér config.env.example til config.env og tilpas."
    exit 1
fi

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { log "FEJL: $*" >&2; exit 1; }

check_root() {
    [[ $EUID -eq 0 ]] || error "Dette script skal køres som root"
}

create_service_user() {
    if ! id "$SERVICE_USER" &>/dev/null; then
        log "Opretter service user: $SERVICE_USER"
        useradd --system --shell /usr/bin/nologin --create-home "$SERVICE_USER"
    else
        log "Service user eksisterer allerede: $SERVICE_USER"
    fi
}

create_directories() {
    log "Opretter mapper..."
    mkdir -p "$DATA_DIR" "$CONFIG_DIR" "$SECRETS_DIR"
    chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chmod 750 "$DATA_DIR"
    chmod 700 "$SECRETS_DIR"
}

install_container() {
    log "Installerer Uptime Kuma container..."
    
    # Pull container
    sudo -u "$SERVICE_USER" podman pull "${IMAGE}:${IMAGE_VERSION}"
    
    # Create data directory structure
    sudo -u "$SERVICE_USER" mkdir -p "${DATA_DIR}/data"
    
    log "Container installeret"
}

install_systemd_service() {
    log "Installerer systemd service..."
    cp "${SCRIPT_DIR}/${ADDON_NAME}.service" "/etc/systemd/system/"
    systemctl daemon-reload
    systemctl enable "$ADDON_NAME"
}

register_backup() {
    log "Registrerer til backup..."
    mkdir -p /etc/humethix
    echo "$DATA_DIR" >> /etc/humethix/backup-paths.conf
    sort -u /etc/humethix/backup-paths.conf -o /etc/humethix/backup-paths.conf
}

register_tunnel() {
    if [[ "${EXPOSE_EXTERNAL:-false}" == "true" ]]; then
        log "Registrerer Cloudflare Tunnel..."
        mkdir -p /etc/humethix
        echo "${SUBDOMAIN}.${DOMAIN:-humethix.dk} http://127.0.0.1:${PORT}" >> /etc/humethix/cloudflare-tunnels.conf
        sort -u /etc/humethix/cloudflare-tunnels.conf -o /etc/humethix/cloudflare-tunnels.conf
        log "Husk at genstarte cloudflared service"
    fi
}

start_service() {
    log "Starter service..."
    systemctl start "$ADDON_NAME"
    
    # Vent op til 60 sekunder på at service starter (Uptime Kuma kan være langsom)
    local retries=60
    while [[ $retries -gt 0 ]] && ! systemctl is-active "$ADDON_NAME" &>/dev/null; do
        sleep 1
        ((retries--))
    done
    
    if systemctl is-active "$ADDON_NAME" &>/dev/null; then
        log "Service started successfully"
        systemctl status "$ADDON_NAME" --no-pager
        
        # Vent yderligere på at web interface er klar
        log "Venter på at web interface bliver klar..."
        sleep 10
        
        # Tjek om web interface svarer
        if curl -f -s "http://127.0.0.1:${PORT}" &>/dev/null; then
            log "Web interface er klar"
        else
            warn "Web interface svarer ikke endnu - tjek logs med: journalctl -u $ADDON_NAME -f"
        fi
    else
        error "Service failed to start. Check logs with: journalctl -u $ADDON_NAME -f"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log "=== Installerer $ADDON_NAME v$ADDON_VERSION ==="
    
    check_root
    create_service_user
    create_directories
    install_container
    install_systemd_service
    register_backup
    register_tunnel
    start_service
    
    log "=== $ADDON_NAME installation fuldført ==="
    log "Uptime Kuma tilgængelig på: http://127.0.0.1:${PORT}"
    if [[ "${EXPOSE_EXTERNAL:-false}" == "true" ]]; then
        log "Ekstern adgang: https://${SUBDOMAIN}.${DOMAIN:-humethix.dk}"
    fi
    log "Første gangs setup: Opret admin konto når du besøger web interface"
}

main "$@"
