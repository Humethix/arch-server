#!/bin/bash
# ============================================================================ 
# VIRTUALBOX OPTIMIZATIONS FOR ARCH LINUX v5.1
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[VB_OPT]${NC} $*"; }
warn() { echo -e "${YELLOW}[VB_OPT]${NC} $*"; }
error() { echo -e "${RED}[VB_OPT]${NC} $*" >&2; }

# Check if running in VirtualBox
check_virtualbox() {
    if [[ ! -f /sys/class/dmi/id/product_name ]]; then
        error "This script is designed for VirtualBox environments"
    fi
    
    local product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")
    if [[ ! "$product_name" =~ VirtualBox ]]; then
        error "VirtualBox not detected. Product: $product_name"
    fi
    
    log "VirtualBox environment detected: $product_name"
}

# Optimize VirtualBox settings
optimize_virtualbox() {
    log "Optimizing VirtualBox settings for Arch Linux..."
    
    # Check VirtualBox Guest Additions
    if [[ -f /usr/bin/VBoxService ]]; then
        log "VirtualBox Guest Additions detected"
    else
        warn "VirtualBox Guest Additions not detected - consider installing for better performance"
    fi
    
    # Optimize kernel parameters for VirtualBox
    log "Optimizing kernel parameters for VirtualBox..."
    
    # Create VirtualBox-specific sysctl configuration
    cat > /etc/sysctl.d/99-virtualbox.conf << 'EOF'
# VirtualBox Optimizations
# Reduce dirty page writeback for better performance in VM
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_writeback_centisecs = 500
vm.dirty_expire_centisecs = 3000

# Optimize I/O scheduler for virtual environments
# Deadline scheduler is generally best for VMs
echo deadline > /sys/block/sda/queue/scheduler 2>/dev/null || true

# Reduce swap usage (VMs have limited I/O)
vm.swappiness = 10

# Optimize networking for VM
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF
    
    sysctl -p /etc/sysctl.d/99-virtualbox.conf
    
    # Optimize systemd for VirtualBox
    log "Optimizing systemd for VirtualBox..."
    
    # Reduce journal size for VMs
    sed -i 's/^#SystemMaxUse=.*/SystemMaxUse=100M/' /etc/systemd/journald.conf 2>/dev/null || true
    sed -i 's/^#RuntimeMaxUse=.*/RuntimeMaxUse=50M/' /etc/systemd/journald.conf 2>/dev/null || true
    
    # Add VirtualBox-specific systemd configuration
    cat > /etc/systemd/system.conf.d/virtualbox.conf << 'EOF'
# VirtualBox Optimizations
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
EOF
    
    # Optimize pacman for VirtualBox
    log "Optimizing pacman for VirtualBox..."
    
    cat >> /etc/pacman.conf << 'EOF'

# VirtualBox Optimizations
# Use parallel downloads for faster package installation
ParallelDownloads = 5
# Disable download timeout for potentially slow VM network
DownloadTimeout = 120
EOF
    
    log "VirtualBox optimizations applied"
}

# Configure VirtualBox-specific services
configure_services() {
    log "Configuring VirtualBox-specific services..."
    
    # Enable VirtualBox Guest Additions service if available
    if systemctl list-unit-files | grep -q "vboxservice"; then
        systemctl enable vboxservice
        systemctl start vboxservice || true
        log "VirtualBox Guest Additions service enabled"
    fi
    
    # Optimize systemd-boot for VirtualBox
    if [[ -d /efi/EFI/systemd ]]; then
        log "Optimizing systemd-boot for VirtualBox..."
        
        # Add VirtualBox-specific boot options
        cat >> /etc/kernel/cmdline << 'EOF'
# VirtualBox Optimizations
# Reduce boot time in VM
quiet splash loglevel=3
# Optimize for virtual environment
systemd.show_status=auto
rd.udev.log_level=3
EOF
    fi
}

# Create VirtualBox-specific performance monitoring
create_monitoring() {
    log "Creating VirtualBox-specific monitoring..."
    
    # Create VirtualBox performance script
    cat > /usr/local/bin/virtualbox-performance << 'EOF'
#!/bin/bash
# VirtualBox Performance Monitor

echo "=== VirtualBox Performance Monitor ==="
echo "Time: $(date)"
echo ""

# CPU Usage
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print "  CPU Usage: " 100 - $5 "%"}'
echo ""

# Memory Usage
echo "Memory Usage:"
free -h | grep -E "^(Mem|Swap)" | awk '{print "  " $1 ": " $3 "/" $2 " (" int($3/$2*100) "%)"}'
echo ""

# Disk I/O
echo "Disk I/O:"
iostat -x 1 1 | tail -n +4 | awk 'NR==1 {print "  " $0} NR>1 {print "  " $0}'
echo ""

# VirtualBox Specific
echo "VirtualBox Info:"
if command -v VBoxManage &>/dev/null; then
    echo "  Guest Additions: $(VBoxManage list vms | head -1 | grep -o 'Guest Additions.*' || echo 'Not detected')"
fi
echo ""
EOF
    
    chmod +x /usr/local/bin/virtualbox-performance
    log "VirtualBox performance monitor created: /usr/local/bin/virtualbox-performance"
}

# Create VirtualBox troubleshooting guide
create_troubleshooting() {
    log "Creating VirtualBox troubleshooting guide..."
    
    cat > /usr/local/bin/virtualbox-troubleshoot << 'EOF'
#!/bin/bash
# VirtualBox Troubleshooting Guide

echo "=== VirtualBox Troubleshooting Guide ==="
echo ""

echo "Common VirtualBox Issues and Solutions:"
echo ""

echo "1. SLOW PERFORMANCE:"
echo "   - Ensure Guest Additions are installed"
echo "   - Enable 3D acceleration in VM settings"
echo "   - Increase video memory to 128MB or more"
echo "   - Enable I/O APIC in VM settings"
echo "   - Use paravirtualized I/O (PVH) if available"
echo ""

echo "2. NETWORK ISSUES:"
echo "   - Use Bridged Adapter for external access"
echo "   - Or use NAT with Port Forwarding"
echo "   - Check VirtualBox network settings"
echo "   - Restart network services: systemctl restart NetworkManager"
echo ""

echo "3. DISPLAY ISSUES:"
echo "   - Install Guest Additions for better graphics"
echo "   - Enable 3D acceleration"
echo "   - Increase video memory"
echo "   - Check display settings in VM"
echo ""

echo "4. STORAGE ISSUES:"
echo "   - Use SATA controller instead of IDE"
echo "   - Enable host I/O cache if needed"
echo "   - Check disk space: df -h"
echo "   - Optimize disk usage: pacman -Scc"
echo ""

echo "5. AUDIO ISSUES:"
echo "   - Enable audio controller in VM settings"
echo "   - Select proper audio driver (PulseAudio or ALSA)"
echo "   - Check audio services: systemctl status pulseaudio"
echo ""

echo "6. SHARED FOLDER ISSUES:"
echo "   - Install Guest Additions for auto-mounting"
echo "   - Check mount points: mount | grep vboxsf"
echo "   - Manual mount: sudo mount -t vboxsf sharename /mount/point"
echo ""

echo "7. TIME SYNC ISSUES:"
echo "   - Enable time sync in VM settings"
echo "   - Or use: timedatectl set-ntp true"
echo "   - Check time: timedatectl status"
echo ""

echo "VirtualBox Version:"
VBoxManage --version 2>/dev/null || echo "VBoxManage not available"
echo ""

echo "System Information:"
echo "  Kernel: $(uname -r)"
echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "  Disk: $(df -h / | tail -1 | awk '{print $2}')"
echo ""
EOF
    
    chmod +x /usr/local/bin/virtualbox-troubleshoot
    log "VirtualBox troubleshooting guide created: /usr/local/bin/virtualbox-troubleshoot"
}

# Main function
main() {
    log "Starting VirtualBox optimizations for Arch Linux v5.1..."
    
    check_virtualbox
    optimize_virtualbox
    configure_services
    create_monitoring
    create_troubleshooting
    
    log "VirtualBox optimizations completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Reboot the system to apply all optimizations"
    echo "2. Run performance monitor: /usr/local/bin/virtualbox-performance"
    echo "3. Check troubleshooting guide: /usr/local/bin/virtualbox-troubleshoot"
    echo "4. Test system performance and functionality"
    echo ""
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
