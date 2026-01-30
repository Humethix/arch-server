#!/bin/bash
# Humethix Addon Manager v1.0
# Brug: addon-manager.sh [install|uninstall|list|status|validate] [addon-navn]

set -euo pipefail

# Configuration
ADDONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVAILABLE_DIR="${ADDONS_DIR}/available"
TEMPLATE_DIR="${ADDONS_DIR}/_template"
LOG_DIR="/var/log/humethix"

# Source hardware detection if available
if [[ -f "${ADDONS_DIR}/../src/hardware-detect.sh" ]]; then
    source "${ADDONS_DIR}/../src/hardware-detect.sh"
    # Run basic detection for addon optimization
    detect_memory
    detect_storage
    detect_cpu
    generate_optimization_profile
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $*"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')]${NC} $*" >&2; exit 1; }

# Ensure log directory exists (only if we have permissions)
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Show usage
show_usage() {
    cat << EOF
Humethix Addon Manager v1.0

Brug: $0 [KOMMANDO] [ADDON_NAVN]

KOMMANDOER:
    install     Installer et addon
    uninstall   Afinstaller et addon
    list        Vis tilgængelige addons
    status      Vis status for installerede addons
    validate    Valider addon struktur

EKSEMPLER:
    $0 install uptime-kuma
    $0 uninstall my-app --purge
    $0 list
    $0 status
    $0 validate my-app

For mere information se addons/README.md
EOF
}

# Check if running as root for operations that need it
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Denne operation kræver root privileges. Brug sudo."
    fi
}

# Check if addon exists
check_addon_exists() {
    local addon_name="$1"
    if [[ ! -d "${AVAILABLE_DIR}/${addon_name}" ]]; then
        error "Addon '${addon_name}' ikke fundet i ${AVAILABLE_DIR}/"
    fi
}

# Check if addon is properly structured
validate_addon_structure() {
    local addon_name="$1"
    local addon_dir="${AVAILABLE_DIR}/${addon_name}"
    
    local required_files=("install.sh" "uninstall.sh" "config.env.example" "${addon_name}.service")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "${addon_dir}/${file}" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error "Addon '${addon_name}' mangler påkrævede filer: ${missing_files[*]}"
    fi
    
    # Check if scripts are executable
    if [[ ! -x "${addon_dir}/install.sh" ]]; then
        warn "install.sh er ikke executable. Sætter permissions..."
        chmod +x "${addon_dir}/install.sh"
    fi
    
    if [[ ! -x "${addon_dir}/uninstall.sh" ]]; then
        warn "uninstall.sh er ikke executable. Sætter permissions..."
        chmod +x "${addon_dir}/uninstall.sh"
    fi
    
    log "Addon '${addon_name}' struktur valideret ✓"
}

# Install addon
install_addon() {
    local addon_name="$1"
    local addon_dir="${AVAILABLE_DIR}/${addon_name}"
    
    check_root
    check_addon_exists "$addon_name"
    validate_addon_structure "$addon_name"
    
    # Check if already installed
    if systemctl is-enabled "${addon_name}" &>/dev/null; then
        warn "Addon '${addon_name}' er allerede installeret"
        read -p "Vil du geninstallere? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation afbrudt"
            return 0
        fi
    fi
    
    # Check if config.env exists
    if [[ ! -f "${addon_dir}/config.env" ]]; then
        warn "config.env ikke fundet. Kopierer fra config.env.example..."
        cp "${addon_dir}/config.env.example" "${addon_dir}/config.env"
        warn "Rediger ${addon_dir}/config.env før du fortsætter"
        read -p "Tryk enter for at fortsætte når config er redigeret..."
    fi
    
    log "Installerer addon '${addon_name}'..."
    
    # Run install script with logging
    if "${addon_dir}/install.sh" 2>&1 | tee "${LOG_DIR}/addon-${addon_name}.log"; then
        log "Addon '${addon_name}' installeret succesfuldt ✓"
        
        # Show service status
        if systemctl is-active "${addon_name}" &>/dev/null; then
            log "Service '${addon_name}' kører"
            systemctl status "${addon_name}" --no-pager -l
        else
            warn "Service '${addon_name}' kører ikke - tjek log: ${LOG_DIR}/addon-${addon_name}.log"
        fi
    else
        error "Installation af '${addon_name}' fejlede. Tjek log: ${LOG_DIR}/addon-${addon_name}.log"
    fi
}

# Uninstall addon
uninstall_addon() {
    local addon_name="$1"
    local addon_dir="${AVAILABLE_DIR}/${addon_name}"
    local purge=false
    
    # Parse arguments
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --purge) purge=true; shift ;;
            *) error "Ukendt argument: $1" ;;
        esac
    done
    
    check_root
    check_addon_exists "$addon_name"
    
    if ! systemctl list-unit-files | grep -q "${addon_name}.service"; then
        warn "Addon '${addon_name}' er ikke installeret"
        return 0
    fi
    
    if [[ "$purge" == "true" ]]; then
        warn "ADVARSEL: Dette vil slette ALLE data for '${addon_name}'"
        read -p "Er du sikker? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Afinstallation afbrudt"
            return 0
        fi
    fi
    
    log "Afinstallerer addon '${addon_name}'..."
    
    # Run uninstall script
    local uninstall_args=()
    if [[ "$purge" == "true" ]]; then
        uninstall_args+=("--purge")
    fi
    
    if "${addon_dir}/uninstall.sh" "${uninstall_args[@]}" 2>&1 | tee "${LOG_DIR}/addon-${addon_name}-uninstall.log"; then
        log "Addon '${addon_name}' afinstalleret succesfuldt ✓"
    else
        error "Afinstallation af '${addon_name}' fejlede. Tjek log: ${LOG_DIR}/addon-${addon_name}-uninstall.log"
    fi
}

# List available addons
list_addons() {
    log "Tilgængelige addons:"
    
    if [[ ! -d "$AVAILABLE_DIR" ]] || [[ -z "$(ls -A "$AVAILABLE_DIR" 2>/dev/null)" ]]; then
        warn "Ingen addons fundet i ${AVAILABLE_DIR}/"
        return 0
    fi
    
    for addon_dir in "${AVAILABLE_DIR}"/*; do
        if [[ -d "$addon_dir" ]]; then
            local addon_name=$(basename "$addon_dir")
            local status=""
            
            # Check if installed
            if systemctl is-enabled "${addon_name}" &>/dev/null; then
                if systemctl is-active "${addon_name}" &>/dev/null; then
                    status="${GREEN}✓ Kører${NC}"
                else
                    status="${YELLOW}⚠ Installeret (inaktiv)${NC}"
                fi
            else
                status="${RED}✗ Ikke installeret${NC}"
            fi
            
            # Get description from README if available
            local description=""
            if [[ -f "${addon_dir}/README.md" ]]; then
                description=$(head -n 3 "${addon_dir}/README.md" | tail -n 1 | sed 's/^#* *//')
            fi
            
            printf "  %-20s %s %s\n" "$addon_name" "$status" "$description"
        fi
    done
}

# Show status of installed addons
show_status() {
    log "Status for installerede addons:"
    
    local installed=false
    for addon_dir in "${AVAILABLE_DIR}"/*; do
        if [[ -d "$addon_dir" ]]; then
            local addon_name=$(basename "$addon_dir")
            
            if systemctl list-unit-files | grep -q "${addon_name}.service"; then
                installed=true
                echo ""
                echo -e "${BLUE}=== ${addon_name} ===${NC}"
                
                # Service status
                if systemctl is-active "${addon_name}" &>/dev/null; then
                    echo -e "Status: ${GREEN}Kører${NC}"
                else
                    echo -e "Status: ${RED}Inaktiv${NC}"
                fi
                
                if systemctl is-enabled "${addon_name}" &>/dev/null; then
                    echo -e "Boot: ${GREEN}Enabled${NC}"
                else
                    echo -e "Boot: ${RED}Disabled${NC}"
                fi
                
                # Resource usage
                if systemctl is-active "${addon_name}" &>/dev/null; then
                    echo "Memory: $(systemctl show "${addon_name}" --property=MemoryCurrent --value | head -c 50)B"
                    echo "CPU: $(systemctl show "${addon_name}" --property=CPUUsageNSec --value | head -c 50)ns"
                fi
                
                # Recent logs
                echo "Seneste logs:"
                journalctl -u "${addon_name}" --no-pager -n 3 --since "1 hour ago" 2>/dev/null | sed 's/^/  /' || echo "  Ingen logs fundet"
            fi
        fi
    done
    
    if [[ "$installed" == "false" ]]; then
        warn "Ingen addons er installeret"
    fi
}

# Validate addon
validate_addon() {
    local addon_name="$1"
    
    check_addon_exists "$addon_name"
    validate_addon_structure "$addon_name"
    
    log "Addon '${addon_name}' er valid og klar til installation ✓"
}

# Create new addon from template
create_addon() {
    local addon_name="$1"
    
    if [[ -d "${AVAILABLE_DIR}/${addon_name}" ]]; then
        error "Addon '${addon_name}' eksisterer allerede"
    fi
    
    if [[ ! -d "$TEMPLATE_DIR" ]]; then
        error "Template mappen ikke fundet: ${TEMPLATE_DIR}"
    fi
    
    log "Opretter nyt addon '${addon_name}' fra skabelon..."
    
    # Copy template
    cp -r "$TEMPLATE_DIR" "${AVAILABLE_DIR}/${addon_name}"
    
    # Replace placeholders in files
    find "${AVAILABLE_DIR}/${addon_name}" -type f -name "*.sh" -o -name "*.service" -o -name "*.example" | while read -r file; do
        sed -i "s/\[ADDON_NAME\]/${addon_name}/g" "$file"
        sed -i "s/\[addon-name\]/${addon_name}/g" "$file"
    done
    
    # Rename service file
    mv "${AVAILABLE_DIR}/${addon_name}/[addon-name].service" "${AVAILABLE_DIR}/${addon_name}/${addon_name}.service"
    
    # Make scripts executable
    chmod +x "${AVAILABLE_DIR}/${addon_name}/install.sh"
    chmod +x "${AVAILABLE_DIR}/${addon_name}/uninstall.sh"
    
    log "Addon '${addon_name}' oprettet ✓"
    warn "Husk at tilpasse filerne i ${AVAILABLE_DIR}/${addon_name}/"
}

# Show help
show_help() {
    cat << EOF
Humethix Addon Manager v1.0

DETAJLER:

install [addon]          Installer et addon
    - Kræver at config.env er konfigureret
    - Logger til /var/log/humethix/addon-[navn].log

uninstall [addon]         Afinstaller et addon (bevarer data)
    --purge               Sletter også alle data

list                      Vis tilgængelige addons med status
    - Viser om de er installeret/kørende

status                    Vis detaljeret status for installerede addons
    - Inkluderer resource usage og logs

validate [addon]          Valider addon struktur
    - Tjekker påkrævede filer
    - Sætter executable permissions

create [addon]            Opret nyt addon fra skabelon
    - Kopierer _template mappen
    - Erstatter placeholders

EKSEMPLER:
    $0 install uptime-kuma
    $0 uninstall my-app --purge
    $0 list
    $0 status
    $0 validate my-app
    $0 create new-service

For mere information se addons/README.md
EOF
}

# Main function
main() {
    # Create directories if they don't exist
    mkdir -p "$AVAILABLE_DIR"
    
    # Parse command
    case "${1:-}" in
        install)
            [[ $# -lt 2 ]] && error "Mangler addon navn"
            install_addon "$2"
            ;;
        uninstall)
            [[ $# -lt 2 ]] && error "Mangler addon navn"
            uninstall_addon "$2" "${@:3}"
            ;;
        list)
            list_addons
            ;;
        status)
            show_status
            ;;
        validate)
            [[ $# -lt 2 ]] && error "Mangler addon navn"
            validate_addon "$2"
            ;;
        create)
            [[ $# -lt 2 ]] && error "Mangler addon navn"
            create_addon "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
