#!/bin/bash
# ============================================================================ 
# HARDWARE DETECTION AND OPTIMIZATION MODULE
# Arch Linux v5.1 - Intelligent Hardware Detection
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global hardware info
declare -A HARDWARE_INFO
declare -A OPTIMIZATION_RECOMMENDATIONS

# Logging
log() { echo -e "${GREEN}[HW_DETECT]${NC} $*"; }
warn() { echo -e "${YELLOW}[HW_DETECT]${NC} $*"; }
error() { echo -e "${RED}[HW_DETECT]${NC} $*" >&2; }
info() { echo -e "${BLUE}[HW_DETECT]${NC} $*"; }

# ============================================================================ 
# CORE HARDWARE DETECTION FUNCTIONS
# ============================================================================

detect_cpu() {
    log "Detecting CPU information..."
    
    local cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(nproc)
    local cpu_threads=$(grep -c '^processor' /proc/cpuinfo)
    local cpu_mhz=$(lscpu | grep 'CPU MHz' | awk '{print $3}' || echo "Unknown")
    local cpu_vendor=$(grep 'vendor_id' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_flags=$(grep 'flags' /proc/cpuinfo | head -1 | cut -d: -f2- | xargs)
    
    HARDWARE_INFO[cpu_model]="$cpu_model"
    HARDWARE_INFO[cpu_cores]="$cpu_cores"
    HARDWARE_INFO[cpu_threads]="$cpu_threads"
    HARDWARE_INFO[cpu_mhz]="$cpu_mhz"
    HARDWARE_INFO[cpu_vendor]="$cpu_vendor"
    HARDWARE_INFO[cpu_flags]="$cpu_flags"
    
    # CPU-specific optimizations
    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        if echo "$cpu_flags" | grep -q "avx2"; then
            OPTIMIZATION_RECOMMENDATIONS[cpu]="Intel CPU with AVX2 detected - optimized compilation flags recommended"
            HARDWARE_INFO[cpu_optimization]="intel-avx2"
        else
            OPTIMIZATION_RECOMMENDATIONS[cpu]="Intel CPU detected - consider CPU-specific optimizations"
            HARDWARE_INFO[cpu_optimization]="intel"
        fi
    elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
        if echo "$cpu_flags" | grep -q "avx2"; then
            OPTIMIZATION_RECOMMENDATIONS[cpu]="AMD CPU with AVX2 detected - optimized compilation flags recommended"
            HARDWARE_INFO[cpu_optimization]="amd-avx2"
        else
            OPTIMIZATION_RECOMMENDATIONS[cpu]="AMD CPU detected - consider CPU-specific optimizations"
            HARDWARE_INFO[cpu_optimization]="amd"
        fi
    fi
    
    log "CPU: $cpu_model ($cpu_cores cores, $cpu_threads threads)"
}

detect_memory() {
    log "Detecting memory information..."
    
    local total_mem=$(free -b | grep '^Mem:' | awk '{print $2}')
    local available_mem=$(free -b | grep '^Mem:' | awk '{print $7}')
    local total_mem_gb=$((total_mem / 1024 / 1024 / 1024))
    local available_mem_gb=$((available_mem / 1024 / 1024 / 1024))
    
    HARDWARE_INFO[memory_total_gb]="$total_mem_gb"
    HARDWARE_INFO[memory_available_gb]="$available_mem_gb"
    HARDWARE_INFO[memory_total_bytes]="$total_mem"
    HARDWARE_INFO[memory_available_bytes]="$available_mem"
    
    # Memory-specific optimizations
    if [[ $total_mem_gb -ge 32 ]]; then
        OPTIMIZATION_RECOMMENDATIONS[memory]="High memory system ($total_mem_gb GB) - enable memory-intensive optimizations"
        HARDWARE_INFO[memory_tier]="high"
    elif [[ $total_mem_gb -ge 16 ]]; then
        OPTIMIZATION_RECOMMENDATIONS[memory]="Medium memory system ($total_mem_gb GB) - balanced optimizations recommended"
        HARDWARE_INFO[memory_tier]="medium"
    elif [[ $total_mem_gb -ge 8 ]]; then
        OPTIMIZATION_RECOMMENDATIONS[memory]="Low memory system ($total_mem_gb GB) - lightweight optimizations recommended"
        HARDWARE_INFO[memory_tier]="low"
    else
        OPTIMIZATION_RECOMMENDATIONS[memory]="Very low memory system ($total_mem_gb GB) - minimal optimizations only"
        HARDWARE_INFO[memory_tier]="minimal"
    fi
    
    log "Memory: ${total_mem_gb}GB total, ${available_mem_gb}GB available"
}

detect_storage() {
    log "Detecting storage information..."
    
    local storage_devices=()
    local total_storage_gb=0
    local ssd_count=0
    local hdd_count=0
    local nvme_count=0
    
    # Get all block devices
    while IFS= read -r device; do
        if [[ -b "$device" ]]; then
            local device_name=$(basename "$device")
            local device_size=$(lsblk -b -n -o SIZE "$device" 2>/dev/null || echo "0")
            local device_size_gb=$((device_size / 1024 / 1024 / 1024))
            local device_rotational=$(lsblk -d -n -o RO "$device" 2>/dev/null || echo "1")
            local device_model=$(lsblk -d -n -o MODEL "$device" 2>/dev/null || echo "Unknown")
            
            # Skip if too small
            if [[ $device_size_gb -lt 1 ]]; then
                continue
            fi
            
            storage_devices+=("$device_name:${device_size_gb}:${device_rotational}:${device_model}")
            total_storage_gb=$((total_storage_gb + device_size_gb))
            
            # Count device types
            if [[ "$device_name" =~ ^nvme ]]; then
                ((nvme_count++))
            elif [[ "$device_rotational" == "0" ]]; then
                ((ssd_count++))
            else
                ((hdd_count++))
            fi
        fi
    done < <(lsblk -d -n -o NAME | grep -E '^(sd|nvme|vd)')
    
    HARDWARE_INFO[storage_total_gb]="$total_storage_gb"
    HARDWARE_INFO[storage_ssd_count]="$ssd_count"
    HARDWARE_INFO[storage_hdd_count]="$hdd_count"
    HARDWARE_INFO[storage_nvme_count]="$nvme_count"
    HARDWARE_INFO[storage_devices]=$(printf '%s\n' "${storage_devices[@]}")
    
    # Storage-specific optimizations
    if [[ $nvme_count -gt 0 ]]; then
        OPTIMIZATION_RECOMMENDATIONS[storage]="NVMe storage detected ($nvme_count devices) - high I/O optimizations recommended"
        HARDWARE_INFO[storage_tier]="nvme"
    elif [[ $ssd_count -gt 0 ]]; then
        OPTIMIZATION_RECOMMENDATIONS[storage]="SSD storage detected ($ssd_count devices) - SSD optimizations recommended"
        HARDWARE_INFO[storage_tier]="ssd"
    else
        OPTIMIZATION_RECOMMENDATIONS[storage]="HDD storage detected ($hdd_count devices) - HDD-specific optimizations recommended"
        HARDWARE_INFO[storage_tier]="hdd"
    fi
    
    log "Storage: ${total_storage_gb}GB total (${nvme_count} NVMe, ${ssd_count} SSD, ${hdd_count} HDD)"
}

detect_gpu() {
    log "Detecting GPU information..."
    
    local gpu_devices=()
    local gpu_count=0
    
    # Check for PCI GPU devices
    while IFS= read -r gpu; do
        if [[ -n "$gpu" ]]; then
            gpu_count=$((gpu_count + 1))
            gpu_devices+=("$gpu")
        fi
    done < <(lspci 2>/dev/null | grep -i 'VGA\|3D\|Display' || true)
    
    # Check for integrated GPU
    local integrated_gpu=""
    if [[ -d "/sys/class/drm" ]]; then
        for drm_device in /sys/class/drm/*; do
            if [[ -L "$drm_device" ]]; then
                local device_path=$(readlink -f "$drm_device")
                if [[ "$device_path" =~ ^/sys/devices/pci.* ]]; then
                    integrated_gpu=$(lspci -s "$(basename "$(dirname "$(dirname "$device_path")")")" 2>/dev/null | grep -i 'VGA\|Display' || echo "")
                    break
                fi
            fi
        done
    fi
    
    HARDWARE_INFO[gpu_count]="$gpu_count"
    HARDWARE_INFO[gpu_devices]=$(printf '%s\n' "${gpu_devices[@]}")
    HARDWARE_INFO[gpu_integrated]="$integrated_gpu"
    
    # GPU-specific optimizations
    if [[ $gpu_count -gt 0 ]]; then
        OPTIMIZATION_RECOMMENDATIONS[gpu]="GPU detected ($gpu_count devices) - consider GPU-accelerated workloads"
        HARDWARE_INFO[gpu_available]="true"
    else
        OPTIMIZATION_RECOMMENDATIONS[gpu]="No dedicated GPU detected - CPU-only workloads"
        HARDWARE_INFO[gpu_available]="false"
    fi
    
    log "GPU: $gpu_count dedicated device(s) detected"
}

detect_network() {
    log "Detecting network information..."
    
    local network_interfaces=()
    local interface_count=0
    
    # Get network interfaces
    while IFS= read -r interface; do
        if [[ -n "$interface" && "$interface" != "lo" ]]; then
            interface_count=$((interface_count + 1))
            local interface_speed=$(ethtool "$interface" 2>/dev/null | grep 'Speed:' | awk '{print $2}' || echo "Unknown")
            local interface_mac=$(ip link show "$interface" | grep -o 'ether [^ ]*' | awk '{print $2}' || echo "Unknown")
            network_interfaces+=("$interface:${interface_speed}:${interface_mac}")
        fi
    done < <(ls /sys/class/net/ | grep -v lo)
    
    HARDWARE_INFO[network_count]="$interface_count"
    HARDWARE_INFO[network_interfaces]=$(printf '%s\n' "${network_interfaces[@]}")
    
    # Network-specific optimizations
    if [[ $interface_count -gt 1 ]]; then
        OPTIMIZATION_RECOMMENDATIONS[network]="Multiple network interfaces detected ($interface_count) - consider network bonding or failover"
        HARDWARE_INFO[network_tier]="multi"
    elif [[ $interface_count -eq 1 ]]; then
        OPTIMIZATION_RECOMMENDATIONS[network]="Single network interface detected - standard network configuration"
        HARDWARE_INFO[network_tier]="single"
    else
        OPTIMIZATION_RECOMMENDATIONS[network]="No network interfaces detected - check network configuration"
        HARDWARE_INFO[network_tier]="none"
    fi
    
    log "Network: $interface_count interface(s) detected"
}

detect_virtualization() {
    log "Detecting virtualization environment..."
    
    local virt_type="none"
    local virt_details=""
    
    if command -v systemd-detect-virt &>/dev/null; then
        virt_type=$(systemd-detect-virt 2>/dev/null || echo "none")
    fi
    
    # Additional virtualization detection
    if [[ "$virt_type" == "none" ]]; then
        if [[ -d /proc/vz ]]; then
            virt_type="openvz"
        elif [[ -f /proc/xen ]]; then
            virt_type="xen"
        elif [[ -d /proc/self/status ]] && grep -q "hypervisor" /proc/self/status; then
            virt_type="hypervisor"
        fi
    fi
    
    # Get virtualization details
    case "$virt_type" in
        "oracle")
            virt_details="VirtualBox detected"
            ;;
        "vmware")
            virt_details="VMware detected"
            ;;
        "kvm")
            virt_details="KVM/QEMU detected"
            ;;
        "microsoft")
            virt_details="Hyper-V detected"
            ;;
        "xen")
            virt_details="Xen detected"
            ;;
        "openvz")
            virt_details="OpenVZ detected"
            ;;
        "hypervisor")
            virt_details="Generic hypervisor detected"
            ;;
        *)
            virt_details="Bare metal system"
            ;;
    esac
    
    HARDWARE_INFO[virtualization_type]="$virt_type"
    HARDWARE_INFO[virtualization_details]="$virt_details"
    
    # Virtualization-specific optimizations
    if [[ "$virt_type" != "none" ]]; then
        OPTIMIZATION_RECOMMENDATIONS[virtualization]="Virtual environment ($virt_type) - virtualization-specific optimizations"
        HARDWARE_INFO[is_bare_metal]="false"
    else
        OPTIMIZATION_RECOMMENDATIONS[virtualization]="Bare metal system - full hardware access optimizations"
        HARDWARE_INFO[is_bare_metal]="true"
    fi
    
    log "Virtualization: $virt_details"
}

detect_tpm() {
    log "Detecting TPM information..."
    
    local tpm_version="none"
    local tpm_device=""
    local tpm_available=false
    
    # Check for TPM 2.0
    if [[ -c /dev/tpm0 ]] || [[ -c /dev/tpmrm0 ]]; then
        if command -v tpm2_startup &>/dev/null; then
            tpm_version="2.0"
            tpm_available=true
            tpm_device="/dev/tpm0"
        elif [[ -c /dev/tpm0 ]]; then
            tpm_version="2.0"
            tpm_available=true
            tpm_device="/dev/tpm0"
        fi
    fi
    
    # Check for TPM 1.2
    if [[ $tpm_available == "false" ]]; then
        if [[ -c /dev/tpm ]] || [[ -d /sys/class/tpm/tpm0 ]]; then
            tpm_version="1.2"
            tpm_available=true
            tpm_device="/dev/tpm"
        fi
    fi
    
    HARDWARE_INFO[tpm_version]="$tpm_version"
    HARDWARE_INFO[tpm_device]="$tpm_device"
    HARDWARE_INFO[tpm_available]="$tpm_available"
    
    # TPM-specific optimizations
    if [[ $tpm_available == "true" ]]; then
        if [[ "$tpm_version" == "2.0" ]]; then
            OPTIMIZATION_RECOMMENDATIONS[tpm]="TPM 2.0 detected - enable TPM-based security features"
            HARDWARE_INFO[tpm_tier]="tpm2"
        else
            OPTIMIZATION_RECOMMENDATIONS[tpm]="TPM 1.2 detected - limited TPM features available"
            HARDWARE_INFO[tpm_tier]="tpm1"
        fi
    else
        OPTIMIZATION_RECOMMENDATIONS[tpm]="No TPM detected - software-based security only"
        HARDWARE_INFO[tpm_tier]="none"
    fi
    
    log "TPM: $tpm_version ($([ "$tpm_available" == "true" ] && echo "available" || echo "not available"))"
}

detect_secure_boot() {
    log "Detecting Secure Boot status..."
    
    local secure_boot="unknown"
    local secure_boot_available=false
    
    if [[ -d /sys/firmware/efi ]]; then
        if command -v mokutil &>/dev/null; then
            if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
                secure_boot="enabled"
                secure_boot_available=true
            elif mokutil --sb-state 2>/dev/null | grep -q "SecureBoot disabled"; then
                secure_boot="disabled"
                secure_boot_available=true
            fi
        fi
        
        # Alternative detection method
        if [[ "$secure_boot" == "unknown" ]]; then
            if [[ -f /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c/data ]]; then
                secure_boot="enabled"
                secure_boot_available=true
            fi
        fi
    else
        secure_boot="not_available"
        secure_boot_available=false
    fi
    
    HARDWARE_INFO[secure_boot_status]="$secure_boot"
    HARDWARE_INFO[secure_boot_available]="$secure_boot_available"
    
    # Secure Boot-specific optimizations
    if [[ "$secure_boot" == "enabled" ]]; then
        OPTIMIZATION_RECOMMENDATIONS[secure_boot]="Secure Boot enabled - maintain key management"
        HARDWARE_INFO[secure_boot_tier]="enabled"
    elif [[ "$secure_boot" == "disabled" ]]; then
        OPTIMIZATION_RECOMMENDATIONS[secure_boot]="Secure Boot disabled - can be enabled for enhanced security"
        HARDWARE_INFO[secure_boot_tier]="disabled"
    else
        OPTIMIZATION_RECOMMENDATIONS[secure_boot]="Secure Boot not available - BIOS/legacy boot"
        HARDWARE_INFO[secure_boot_tier]="unavailable"
    fi
    
    log "Secure Boot: $secure_boot"
}

# ============================================================================ 
# OPTIMIZATION ENGINE
# ============================================================================

generate_optimization_profile() {
    log "Generating hardware optimization profile..."
    
    local profile_name=""
    local optimization_level=""
    local recommendations=()
    
    # Determine optimization level based on hardware
    if [[ "${HARDWARE_INFO[memory_tier]}" == "high" ]] && [[ "${HARDWARE_INFO[storage_tier]}" == "nvme" ]]; then
        optimization_level="performance"
        profile_name="high-performance"
    elif [[ "${HARDWARE_INFO[memory_tier]}" == "medium" ]] && [[ "${HARDWARE_INFO[storage_tier]}" =~ ^(ssd|nvme)$ ]]; then
        optimization_level="balanced"
        profile_name="balanced"
    else
        optimization_level="minimal"
        profile_name="minimal"
    fi
    
    # Add specific recommendations
    for category in "${!OPTIMIZATION_RECOMMENDATIONS[@]}"; do
        recommendations+=("${OPTIMIZATION_RECOMMENDATIONS[$category]}")
    done
    
    HARDWARE_INFO[optimization_profile]="$profile_name"
    HARDWARE_INFO[optimization_level]="$optimization_level"
    HARDWARE_INFO[recommendations]=$(printf '%s\n' "${recommendations[@]}")
    
    log "Optimization profile: $profile_name ($optimization_level)"
}

generate_hardware_report() {
    log "Generating comprehensive hardware report..."
    
    local report_file="/tmp/hardware-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "hardware": {
        "cpu": {
            "model": "${HARDWARE_INFO[cpu_model]}",
            "vendor": "${HARDWARE_INFO[cpu_vendor]}",
            "cores": ${HARDWARE_INFO[cpu_cores]},
            "threads": ${HARDWARE_INFO[cpu_threads]},
            "mhz": "${HARDWARE_INFO[cpu_mhz]}",
            "optimization": "${HARDWARE_INFO[cpu_optimization]}"
        },
        "memory": {
            "total_gb": ${HARDWARE_INFO[memory_total_gb]},
            "available_gb": ${HARDWARE_INFO[memory_available_gb]},
            "total_bytes": ${HARDWARE_INFO[memory_total_bytes]},
            "tier": "${HARDWARE_INFO[memory_tier]}"
        },
        "storage": {
            "total_gb": ${HARDWARE_INFO[storage_total_gb]},
            "ssd_count": ${HARDWARE_INFO[storage_ssd_count]},
            "hdd_count": ${HARDWARE_INFO[storage_hdd_count]},
            "nvme_count": ${HARDWARE_INFO[storage_nvme_count]},
            "tier": "${HARDWARE_INFO[storage_tier]}"
        },
        "gpu": {
            "count": ${HARDWARE_INFO[gpu_count]},
            "available": "${HARDWARE_INFO[gpu_available]}",
            "integrated": "${HARDWARE_INFO[gpu_integrated]}"
        },
        "network": {
            "interface_count": ${HARDWARE_INFO[network_count]},
            "tier": "${HARDWARE_INFO[network_tier]}"
        },
        "virtualization": {
            "type": "${HARDWARE_INFO[virtualization_type]}",
            "details": "${HARDWARE_INFO[virtualization_details]}",
            "is_bare_metal": ${HARDWARE_INFO[is_bare_metal]}
        },
        "security": {
            "tpm": {
                "version": "${HARDWARE_INFO[tpm_version]}",
                "available": ${HARDWARE_INFO[tpm_available]},
                "device": "${HARDWARE_INFO[tpm_device]}",
                "tier": "${HARDWARE_INFO[tpm_tier]}"
            },
            "secure_boot": {
                "status": "${HARDWARE_INFO[secure_boot_status]}",
                "available": ${HARDWARE_INFO[secure_boot_available]},
                "tier": "${HARDWARE_INFO[secure_boot_tier]}"
            }
        }
    },
    "optimization": {
        "profile": "${HARDWARE_INFO[optimization_profile]}",
        "level": "${HARDWARE_INFO[optimization_level]}",
        "recommendations": $(printf '%s\n' "${HARDWARE_INFO[recommendations]}" | jq -R . | jq -s .)
    }
}
EOF
    
    echo "Hardware report saved to: $report_file"
    HARDWARE_INFO[report_file]="$report_file"
}

# ============================================================================ 
# MAIN FUNCTION
# ============================================================================

main() {
    log "Starting comprehensive hardware detection..."
    
    # Run all detection functions
    detect_cpu
    detect_memory
    detect_storage
    detect_gpu
    detect_network
    detect_virtualization
    detect_tpm
    detect_secure_boot
    
    # Generate optimization profile
    generate_optimization_profile
    
    # Generate report
    generate_hardware_report
    
    # Display summary
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    HARDWARE DETECTION SUMMARY                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${CYAN}SYSTEM INFORMATION:${NC}"
    echo "  Hostname: $(hostname)"
    echo "  Virtualization: ${HARDWARE_INFO[virtualization_details]}"
    echo "  Bare Metal: ${HARDWARE_INFO[is_bare_metal]}"
    echo ""
    echo -e "${CYAN}PROCESSOR:${NC}"
    echo "  Model: ${HARDWARE_INFO[cpu_model]}"
    echo "  Cores/Threads: ${HARDWARE_INFO[cpu_cores]}/${HARDWARE_INFO[cpu_threads]}"
    echo "  Optimization: ${HARDWARE_INFO[cpu_optimization]}"
    echo ""
    echo -e "${CYAN}MEMORY:${NC}"
    echo "  Total: ${HARDWARE_INFO[memory_total_gb]}GB"
    echo "  Available: ${HARDWARE_INFO[memory_available_gb]}GB"
    echo "  Tier: ${HARDWARE_INFO[memory_tier]}"
    echo ""
    echo -e "${CYAN}STORAGE:${NC}"
    echo "  Total: ${HARDWARE_INFO[storage_total_gb]}GB"
    echo "  SSD/HDD/NVMe: ${HARDWARE_INFO[storage_ssd_count]}/${HARDWARE_INFO[storage_hdd_count]}/${HARDWARE_INFO[storage_nvme_count]}"
    echo "  Tier: ${HARDWARE_INFO[storage_tier]}"
    echo ""
    echo -e "${CYAN}SECURITY:${NC}"
    echo "  TPM: ${HARDWARE_INFO[tpm_version]} (${HARDWARE_INFO[tpm_available]})"
    echo "  Secure Boot: ${HARDWARE_INFO[secure_boot_status]} (${HARDWARE_INFO[secure_boot_available]})"
    echo ""
    echo -e "${CYAN}OPTIMIZATION PROFILE:${NC}"
    echo "  Profile: ${HARDWARE_INFO[optimization_profile]}"
    echo "  Level: ${HARDWARE_INFO[optimization_level]}"
    echo ""
    echo -e "${CYAN}RECOMMENDATIONS:${NC}"
    printf '%s\n' "${HARDWARE_INFO[recommendations]}" | sed 's/^/  • /'
    echo ""
    echo -e "${GREEN}Report saved to: ${HARDWARE_INFO[report_file]}${NC}"
    echo ""
}

# Export hardware info for other scripts
export_hardware_info() {
    for key in "${!HARDWARE_INFO[@]}"; do
        export "HW_$key=${HARDWARE_INFO[$key]}"
    done
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    export_hardware_info
fi
