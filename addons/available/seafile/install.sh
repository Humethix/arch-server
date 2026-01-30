#!/bin/bash
set -euo pipefail

# =============================================================================
# Seafile Installation Script
# Humethix Addon System v1.0
# =============================================================================

ADDON_NAME="seafile"
ADDON_VERSION="1.0.0"

# Paths
DATA_DIR="/mnt/data/${ADDON_NAME}"
CONFIG_DIR="/etc/humethix/${ADDON_NAME}"
SECRETS_DIR="/etc/humethix/secrets/${ADDON_NAME}"
SERVICE_USER="${ADDON_NAME}"

# Storage paths
STORAGE_MOUNT="/mnt/seafile-storage"
SEAFILE_DATA_DIR="${STORAGE_MOUNT}/seafile-data"
CCNET_DIR="${STORAGE_MOUNT}/ccnet"
CONF_DIR="${STORAGE_MOUNT}/conf"
SEAFILE_DIR="${STORAGE_MOUNT}/seafile"
SEAHUB_DIR="${STORAGE_MOUNT}/seahub-data"

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

# ============================================================================ 
# HARDWARE-BASED OPTIMIZATION
# ============================================================================

# Source hardware detection if available
if [[ -f "${SCRIPT_DIR}/../../src/hardware-detect.sh" ]]; then
    source "${SCRIPT_DIR}/../../src/hardware-detect.sh"
    
    # Run hardware detection for optimization
    detect_cpu
    detect_memory
    
    # Export hardware info for use in this script
    export_hardware_info
    
    log "Applying hardware-based optimizations for Seafile..."
    
    # Optimize memory limits based on available memory
    local available_memory_gb=${HW_memory_available_gb}
    if [[ $available_memory_gb -ge 16 ]]; then
        # High-end system
        SERVER_MEMORY_LIMIT=${SERVER_MEMORY_LIMIT:-"2g"}
        DB_MEMORY_LIMIT=${DB_MEMORY_LIMIT:-"1g"}
        REDIS_MEMORY_LIMIT=${REDIS_MEMORY_LIMIT:-"512m"}
        MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-"500"}
        log "High-end memory system detected (${available_memory_gb}GB) - using high-performance settings"
    elif [[ $available_memory_gb -ge 8 ]]; then
        # Medium system
        SERVER_MEMORY_LIMIT=${SERVER_MEMORY_LIMIT:-"1g"}
        DB_MEMORY_LIMIT=${DB_MEMORY_LIMIT:-"512m"}
        REDIS_MEMORY_LIMIT=${REDIS_MEMORY_LIMIT:-"256m"}
        MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-"200"}
        log "Medium memory system detected (${available_memory_gb}GB) - using balanced settings"
    else
        # Low-end system
        SERVER_MEMORY_LIMIT=${SERVER_MEMORY_LIMIT:-"512m"}
        DB_MEMORY_LIMIT=${DB_MEMORY_LIMIT:-"256m"}
        REDIS_MEMORY_LIMIT=${REDIS_MEMORY_LIMIT:-"128m"}
        MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-"100"}
        log "Low memory system detected (${available_memory_gb}GB) - using lightweight settings"
    fi
    
    # Optimize CPU settings based on available cores
    local cpu_cores=${HW_cpu_cores}
    if [[ $cpu_cores -ge 4 ]]; then
        # High-end CPU
        SERVER_CPU_LIMIT=${SERVER_CPU_LIMIT:-"2.0"}
        DB_CPU_LIMIT=${DB_CPU_LIMIT:-"1.5"}
        log "High-end CPU detected (${cpu_cores} cores) - optimized for parallel processing"
    elif [[ $cpu_cores -ge 2 ]]; then
        # Medium CPU
        SERVER_CPU_LIMIT=${SERVER_CPU_LIMIT:-"1.5"}
        DB_CPU_LIMIT=${DB_CPU_LIMIT:-"1.0"}
        log "Medium CPU detected (${cpu_cores} cores) - using balanced CPU settings"
    else
        # Low-end CPU
        SERVER_CPU_LIMIT=${SERVER_CPU_LIMIT:-"1.0"}
        DB_CPU_LIMIT=${DB_CPU_LIMIT:-"0.5"}
        log "Low-end CPU detected (${cpu_cores} cores) - using conservative CPU settings"
    fi
    
    # Optimize based on storage type
    if [[ "${HW_storage_tier}" == "nvme" ]]; then
        log "NVMe storage detected - optimizing for high I/O workloads"
        # Can handle more concurrent operations
        MAX_CONCURRENT_UPLOADS=${MAX_CONCURRENT_UPLOADS:-"10"}
    elif [[ "${HW_storage_tier}" == "hdd" ]]; then
        log "HDD storage detected - optimizing for lower I/O impact"
        # Reduce concurrent operations to avoid I/O bottleneck
        MAX_CONCURRENT_UPLOADS=${MAX_CONCURRENT_UPLOADS:-"2"}
        MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE:-"50"}
    else
        MAX_CONCURRENT_UPLOADS=${MAX_CONCURRENT_UPLOADS:-"5"}
    fi
    
    log "Hardware-optimized Seafile configuration applied"
else
    warn "Hardware detection not available - using default Seafile configuration"
fi

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { log "FEJL: $*" >&2; exit 1; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ADVARSEL: $*"; }

check_root() {
    [[ $EUID -eq 0 ]] || error "Dette script skal køres som root"
}

validate_storage_device() {
    if [[ -z "${STORAGE_DEVICE:-}" ]]; then
        error "STORAGE_DEVICE er påkrævet i config.env"
    fi
    
    if [[ ! -b "$STORAGE_DEVICE" ]]; then
        error "Storage device '$STORAGE_DEVICE' eksisterer ikke: $STORAGE_DEVICE"
    fi
    
    # Tjek om drevet allerede er mountet
    if findmnt -rn -S "$STORAGE_DEVICE" &>/dev/null; then
        local mount_point=$(findmnt -rn -S "$STORAGE_DEVICE" -o TARGET)
        warn "Storage device er allerede mountet på: $mount_point"
        read -p "Vil du bruge eksisterende mount? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Afbryd installation. Vælg et andet STORAGE_DEVICE eller afmount først."
        fi
        STORAGE_MOUNT="$mount_point"
        return 0
    fi
    
    # Hent drev størrelse
    local device_size_bytes=$(lsblk -b -n -o SIZE "$STORAGE_DEVICE" | head -n1)
    local device_size_gb=$((device_size_bytes / 1024 / 1024 / 1024))
    
    log "Fundet storage device: $STORAGE_DEVICE (${device_size_gb}GB)"
    
    if [[ $device_size_gb -lt $MIN_STORAGE_GB ]]; then
        error "Storage device er for lille. Kræver mindst ${MIN_STORAGE_GB}GB, fundet ${device_size_gb}GB"
    fi
    
    # Spørg om formatering
    echo ""
    warn "Dette vil FORMATERE og slette ALT data på: $STORAGE_DEVICE"
    echo "Device størrelse: ${device_size_gb}GB"
    echo "Minimum krav: ${MIN_STORAGE_GB}GB"
    echo ""
    read -p "Er du sikker på du vil fortsætte? [skriv 'JA' for at bekræfte]: " -r
    echo
    if [[ ! $REPLY == "JA" ]]; then
        error "Installation afbrudt for at beskytte data"
    fi
    
    return 0
}

setup_storage() {
    log "Opsætning af storage device: $STORAGE_DEVICE"
    
    # Hvis drevet ikke er mountet, formater og mount det
    if ! findmnt -rn -S "$STORAGE_DEVICE" &>/dev/null; then
        log "Formaterer storage device med ext4..."
        
        # Opret partitionstabel hvis nødvendigt
        if ! blkid "$STORAGE_DEVICE" &>/dev/null; then
            log "Opretter ny partitionstabel..."
            wipefs -a "$STORAGE_DEVICE"
            sfdisk "$STORAGE_DEVICE" << EOF
label: gpt
size: , type=LINUX
EOF
            partprobe "$STORAGE_DEVICE"
            # Vent på at device er klar
            sleep 2
            
            # Brug partitionen (hvis der blev oprettet en)
            if [[ -b "${STORAGE_DEVICE}1" ]]; then
                STORAGE_DEVICE="${STORAGE_DEVICE}1"
            fi
        fi
        
        # Formater med ext4
        log "Formaterer $STORAGE_DEVICE med ext4..."
        mkfs.ext4 -F -L "seafile-storage" "$STORAGE_DEVICE"
        
        # Opret mount point
        mkdir -p "$STORAGE_MOUNT"
        
        # Tilføj til /etc/fstab
        local uuid=$(blkid -s UUID -o value "$STORAGE_DEVICE")
        echo "UUID=$uuid $STORAGE_MOUNT ext4 defaults,noatime 0 2" >> /etc/fstab
        
        # Mount drevet
        mount "$STORAGE_MOUNT"
        
        log "Storage device formateret og mountet på $STORAGE_MOUNT"
    else
        log "Bruger eksisterende mount på $STORAGE_MOUNT"
    fi
    
    # Opret Seafile directory struktur
    log "Opretter Seafile directory struktur..."
    mkdir -p "$SEAFILE_DATA_DIR" "$CCNET_DIR" "$CONF_DIR" "$SEAFILE_DIR" "$SEAHUB_DIR"
    
    # Sæt permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$STORAGE_MOUNT"
    chmod 755 "$STORAGE_MOUNT"
    chmod 755 "$SEAFILE_DATA_DIR" "$CCNET_DIR" "$CONF_DIR" "$SEAFILE_DIR" "$SEAHUB_DIR"
    
    log "Storage setup fuldført"
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

generate_secrets() {
    log "Genererer secrets..."
    
    # Generer database password
    if [[ ! -f "${SECRETS_DIR}/db_password" ]]; then
        openssl rand -base64 32 > "${SECRETS_DIR}/db_password"
        chmod 600 "${SECRETS_DIR}/db_password"
    fi
    
    # Generer Seafile secrets
    if [[ ! -f "${SECRETS_DIR}/seafile_secret_key" ]]; then
        openssl rand -hex 16 > "${SECRETS_DIR}/seafile_secret_key"
        chmod 600 "${SECRETS_DIR}/seafile_secret_key"
    fi
    
    # Generer admin password hvis ikke sat
    if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
        if [[ ! -f "${SECRETS_DIR}/admin_password" ]]; then
            openssl rand -base64 16 > "${SECRETS_DIR}/admin_password"
            chmod 600 "${SECRETS_DIR}/admin_password"
        fi
        ADMIN_PASSWORD=$(cat "${SECRETS_DIR}/admin_password")
    fi
    
    chown -R "$SERVICE_USER:$SERVICE_USER" "$SECRETS_DIR"
}

install_containers() {
    log "Installerer Seafile containers..."
    
    # Pull images
    local images=(
        "seafileltd/seafile-mc:${SEAFILE_VERSION}"
        "mariadb:10.11"
        "redis:7-alpine"
        "memcached:1.6-alpine"
    )
    
    for image in "${images[@]}"; do
        log "Puller $image..."
        sudo -u "$SERVICE_USER" podman pull "$image"
    done
    
    log "Containers installeret"
}

create_docker_compose() {
    log "Opretter docker-compose konfiguration..."
    
    local db_password=$(cat "${SECRETS_DIR}/db_password")
    local seafile_secret_key=$(cat "${SECRETS_DIR}/seafile_secret_key")
    
    cat > "${CONFIG_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  seafile:
    image: seafileltd/seafile-mc:${SEAFILE_VERSION}
    container_name: seafile
    ports:
      - 127.0.0.1:${WEB_PORT}:80
      - 127.0.0.1:${FILE_SERVER_PORT}:8082
    volumes:
      - ${SEAFILE_DATA_DIR}:/shared/seafile:Z
      - ${CCNET_DIR}:/shared/ccnet:Z
      - ${CONF_DIR}:/shared/conf:Z
      - ${SEAFILE_DIR}:/shared/seafile-server:Z
      - ${SEAHUB_DIR}:/shared/seahub-data:Z
    environment:
      - DB_HOST=db
      - DB_ROOT_PASSWD=${db_password}
      - TIMEZONE=${TIMEZONE:-Europe/Copenhagen}
      - SEAFILE_ADMIN_EMAIL=${ADMIN_EMAIL}
      - SEAFILE_ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - SEAFILE_SERVER_LETSENCRYPT=false
      - SEAFILE_SERVER_HOSTNAME=localhost
      - SEAFILE_FILE_SERVER_ROOT=http://127.0.0.1:${FILE_SERVER_PORT}
      - SEAFILE_SECRET_KEY=${seafile_secret_key}
      - MAX_UPLOAD_SIZE=${MAX_UPLOAD_SIZE}
      - MAX_NUMBER_OF_FILES=${MAX_NUMBER_OF_FILES}
      - ENABLE_FILE_HISTORY=${ENABLE_FILE_HISTORY}
      - FILE_HISTORY_KEEP_DAYS=${FILE_HISTORY_KEEP_DAYS}
    depends_on:
      - db
      - memcached
      - redis
    restart: unless-stopped

  db:
    image: mariadb:10.11
    container_name: seafile-db
    environment:
      - MYSQL_ROOT_PASSWORD=${db_password}
      - MYSQL_LOG_CONSOLE=true
    volumes:
      - ${DATA_DIR}/mysql:/var/lib/mysql:Z
    restart: unless-stopped

  memcached:
    image: memcached:1.6-alpine
    container_name: seafile-memcached
    entrypoint: memcached -m 256
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: seafile-redis
    restart: unless-stopped
EOF

    chown "$SERVICE_USER:$SERVICE_USER" "${CONFIG_DIR}/docker-compose.yml"
}

create_seafile_conf() {
    log "Opretter Seafile konfigurationsfiler..."
    
    # Opret seafile.conf
    cat > "${CONF_DIR}/seafile.conf" << EOF
[fileserver]
port = ${FILE_SERVER_PORT}

[database]
host = db
port = 3306
user = root
password = $(cat "${SECRETS_DIR}/db_password")
db_name = seafile
connection_charset = utf8

[storage]
seafile_data_dir = ${SEAFILE_DATA_DIR}

[quota]
default_quota = 50000000000

[history]
keep_days = ${FILE_HISTORY_KEEP_DAYS}
EOF

    chown "$SERVICE_USER:$SERVICE_USER" "${CONF_DIR}/seafile.conf"
}

install_systemd_service() {
    log "Installerer systemd service..."
    
    cat > "/etc/systemd/system/${ADDON_NAME}.service" << EOF
[Unit]
Description=Seafile File Service (Humethix)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${CONFIG_DIR}

# Start containers
ExecStart=/usr/bin/podman-compose -f ${CONFIG_DIR}/docker-compose.yml up -d

# Stop containers
ExecStop=/usr/bin/podman-compose -f ${CONFIG_DIR}/docker-compose.yml down

# Get status
ExecStatus=/usr/bin/podman-compose -f ${CONFIG_DIR}/docker-compose.yml ps

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$ADDON_NAME"
}

register_backup() {
    log "Registrerer til backup..."
    mkdir -p /etc/humethix
    echo "$STORAGE_MOUNT" >> /etc/humethix/backup-paths.conf
    echo "$DATA_DIR" >> /etc/humethix/backup-paths.conf
    sort -u /etc/humethix/backup-paths.conf -o /etc/humethix/backup-paths.conf
}

register_tunnel() {
    if [[ "${EXPOSE_EXTERNAL:-false}" == "true" ]]; then
        log "Registrerer Cloudflare Tunnel..."
        mkdir -p /etc/humethix
        echo "${SUBDOMAIN}.${DOMAIN:-humethix.dk} http://127.0.0.1:${WEB_PORT}" >> /etc/humethix/cloudflare-tunnels.conf
        sort -u /etc/humethix/cloudflare-tunnels.conf -o /etc/humethix/cloudflare-tunnels.conf
        log "Husk at genstarte cloudflared service"
    fi
}

start_service() {
    log "Starter Seafile service..."
    systemctl start "$ADDON_NAME"
    
    # Vent på at containers starter
    log "Venter på at Seafile starter (dette kan tage et par minutter)..."
    sleep 45
    
    # Tjek om web interface svarer
    local retries=60
    while [[ $retries -gt 0 ]]; do
        if curl -f -s "http://127.0.0.1:${WEB_PORT}" &>/dev/null; then
            log "Seafile web interface er klar!"
            break
        fi
        sleep 2
        ((retries--))
        echo -n "."
    done
    echo ""
    
    if [[ $retries -eq 0 ]]; then
        warn "Seafile web interface svarer ikke endnu - tjek logs med: journalctl -u $ADDON_NAME -f"
    else
        log "Seafile started successfully"
        systemctl status "$ADDON_NAME" --no-pager
    fi
}

show_admin_info() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  SEAFILE ADMIN INFORMATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Admin Email: ${ADMIN_EMAIL}"
    echo "Admin Password: ${ADMIN_PASSWORD}"
    echo ""
    echo "Web Interface: http://127.0.0.1:${WEB_PORT}"
    if [[ "${EXPOSE_EXTERNAL:-false}" == "true" ]]; then
        echo "Ekstern adgang: https://${SUBDOMAIN}.${DOMAIN:-humethix.dk}"
    fi
    echo ""
    
    # Vis storage usage
    if [[ -d "$STORAGE_MOUNT" ]]; then
        echo "Storage Usage:"
        df -h "$STORAGE_MOUNT"
        echo ""
        echo "Directory Sizes:"
        du -sh "$SEAFILE_DATA_DIR" "$CCNET_DIR" "$CONF_DIR" "$SEAFILE_DIR" "$SEAHUB_DIR" 2>/dev/null || echo "Directories not yet created"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log "=== Installerer $ADDON_NAME v$ADDON_VERSION ==="
    
    check_root
    validate_storage_device
    create_service_user
    create_directories
    setup_storage
    generate_secrets
    install_containers
    create_docker_compose
    create_seafile_conf
    install_systemd_service
    register_backup
    register_tunnel
    start_service
    show_admin_info
    
    log "=== $ADDON_NAME installation fuldført ==="
    log "Seafile er klar til brug!"
    log "Login med admin credentials ovenfor for at konfigurere systemet"
}

main "$@"
