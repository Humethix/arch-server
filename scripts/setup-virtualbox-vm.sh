#!/bin/bash
# ============================================================================
# VIRTUALBOX VM SETUP SCRIPT v5.1
# Creates a properly configured VirtualBox VM for Arch Server testing
# ============================================================================
#
# REQUIREMENTS:
#   - VirtualBox 7.0+ installed (for TPM support)
#   - VBoxManage in PATH
#   - Arch Linux ISO downloaded
#
# USAGE:
#   ./setup-virtualbox-vm.sh [options]
#
# OPTIONS:
#   --name NAME         VM name (default: arch-server-test)
#   --iso PATH          Path to Arch Linux ISO (required)
#   --ram MB            RAM in MB (default: 4096)
#   --disk GB           Disk size in GB (default: 30)
#   --cpus N            Number of CPUs (default: 2)
#   --bridge ADAPTER    Use bridged networking with this adapter
#   --no-tpm            Disable TPM 2.0
#   --no-efi            Use BIOS instead of EFI (not recommended)
#   --start             Start VM after creation
#   --delete            Delete existing VM with same name first
#
# EXAMPLES:
#   ./setup-virtualbox-vm.sh --iso ~/Downloads/archlinux-2024.01.01-x86_64.iso
#   ./setup-virtualbox-vm.sh --iso arch.iso --name test-vm --ram 8192 --start
#   ./setup-virtualbox-vm.sh --iso arch.iso --bridge "Intel(R) Ethernet" --start
#
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}>>>${NC} $1"; }
success() { echo -e "${GREEN}OK${NC} $1"; }
warning() { echo -e "${YELLOW}!!${NC} $1"; }
error() { echo -e "${RED}ERROR${NC} $1"; exit 1; }

# Default values
VM_NAME="arch-server-test"
ISO_PATH=""
RAM_MB=4096
DISK_GB=30
CPUS=2
BRIDGE_ADAPTER=""
ENABLE_TPM=true
ENABLE_EFI=true
START_VM=false
DELETE_EXISTING=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name) VM_NAME="$2"; shift 2 ;;
        --iso) ISO_PATH="$2"; shift 2 ;;
        --ram) RAM_MB="$2"; shift 2 ;;
        --disk) DISK_GB="$2"; shift 2 ;;
        --cpus) CPUS="$2"; shift 2 ;;
        --bridge) BRIDGE_ADAPTER="$2"; shift 2 ;;
        --no-tpm) ENABLE_TPM=false; shift ;;
        --no-efi) ENABLE_EFI=false; shift ;;
        --start) START_VM=true; shift ;;
        --delete) DELETE_EXISTING=true; shift ;;
        --help|-h)
            head -50 "$0" | tail -n +2 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *) error "Unknown option: $1" ;;
    esac
done

# ============================================================================
# VALIDATION
# ============================================================================

cat << "EOF"
+--------------------------------------------------------------+
|   VIRTUALBOX VM SETUP v5.1                                   |
|   Creates a properly configured VM for Arch Server testing   |
+--------------------------------------------------------------+
EOF
echo ""

# Check VBoxManage
if ! command -v VBoxManage &>/dev/null; then
    error "VBoxManage not found! Install VirtualBox and ensure it's in PATH."
fi

VB_VERSION=$(VBoxManage --version | cut -d'r' -f1)
log "VirtualBox version: $VB_VERSION"

# Check version for TPM support
VB_MAJOR=$(echo "$VB_VERSION" | cut -d'.' -f1)
if [[ "$VB_MAJOR" -lt 7 ]] && [[ "$ENABLE_TPM" == "true" ]]; then
    warning "VirtualBox $VB_VERSION detected - TPM 2.0 requires version 7.0+"
    warning "Disabling TPM support"
    ENABLE_TPM=false
fi

# Check ISO
if [[ -z "$ISO_PATH" ]]; then
    error "ISO path required! Use --iso /path/to/archlinux.iso"
fi

if [[ ! -f "$ISO_PATH" ]]; then
    error "ISO not found: $ISO_PATH"
fi
success "ISO found: $ISO_PATH"

# Check if VM already exists
if VBoxManage showvminfo "$VM_NAME" &>/dev/null; then
    if [[ "$DELETE_EXISTING" == "true" ]]; then
        log "Deleting existing VM: $VM_NAME"
        VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
        success "Existing VM deleted"
    else
        error "VM '$VM_NAME' already exists! Use --delete to remove it first."
    fi
fi

# ============================================================================
# CREATE VM
# ============================================================================

log "Creating VM: $VM_NAME"
echo "  RAM: ${RAM_MB}MB"
echo "  Disk: ${DISK_GB}GB"
echo "  CPUs: $CPUS"
echo "  EFI: $ENABLE_EFI"
echo "  TPM: $ENABLE_TPM"
echo ""

# Get VirtualBox VM folder
VM_FOLDER=$(VBoxManage list systemproperties | grep "Default machine folder" | cut -d':' -f2 | xargs)
VM_PATH="$VM_FOLDER/$VM_NAME"
DISK_PATH="$VM_PATH/$VM_NAME.vdi"

# Create VM
VBoxManage createvm --name "$VM_NAME" --ostype "ArchLinux_64" --register
success "VM created"

# Configure system settings
log "Configuring system settings..."

# Basic settings
VBoxManage modifyvm "$VM_NAME" \
    --memory "$RAM_MB" \
    --cpus "$CPUS" \
    --vram 16 \
    --graphicscontroller vmsvga \
    --audio-driver none \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none

# EFI settings
if [[ "$ENABLE_EFI" == "true" ]]; then
    VBoxManage modifyvm "$VM_NAME" --firmware efi64
    success "EFI firmware enabled"
else
    warning "Using BIOS mode - Secure Boot and UKI will not work!"
fi

# TPM settings (VirtualBox 7+)
if [[ "$ENABLE_TPM" == "true" ]]; then
    VBoxManage modifyvm "$VM_NAME" --tpm-type 2.0
    success "TPM 2.0 enabled"
fi

# Network settings
log "Configuring network..."
if [[ -n "$BRIDGE_ADAPTER" ]]; then
    VBoxManage modifyvm "$VM_NAME" \
        --nic1 bridged \
        --bridgeadapter1 "$BRIDGE_ADAPTER"
    success "Bridged networking: $BRIDGE_ADAPTER"
else
    VBoxManage modifyvm "$VM_NAME" \
        --nic1 nat \
        --natpf1 "SSH,tcp,,2222,,22" \
        --natpf1 "HTTP,tcp,,8080,,80" \
        --natpf1 "HTTPS,tcp,,8443,,443"
    success "NAT networking with port forwarding (SSH:2222, HTTP:8080, HTTPS:8443)"
fi

# Create storage controller
log "Creating storage..."

# SATA controller for disk
VBoxManage storagectl "$VM_NAME" \
    --name "SATA" \
    --add sata \
    --controller IntelAhci \
    --portcount 2

# Create virtual disk
VBoxManage createmedium disk \
    --filename "$DISK_PATH" \
    --size $((DISK_GB * 1024)) \
    --format VDI \
    --variant Standard

# Attach disk
VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "$DISK_PATH"

success "Virtual disk created: ${DISK_GB}GB"

# Attach ISO
VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "$ISO_PATH"

success "ISO attached"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "================================================================"
echo "  VM CREATED SUCCESSFULLY"
echo "================================================================"
echo ""
echo "  VM Name: $VM_NAME"
echo "  VM Path: $VM_PATH"
echo ""
echo "  Settings:"
echo "    - RAM: ${RAM_MB}MB"
echo "    - Disk: ${DISK_GB}GB ($DISK_PATH)"
echo "    - CPUs: $CPUS"
echo "    - Firmware: $(if [[ "$ENABLE_EFI" == "true" ]]; then echo "EFI"; else echo "BIOS"; fi)"
echo "    - TPM 2.0: $(if [[ "$ENABLE_TPM" == "true" ]]; then echo "Enabled"; else echo "Disabled"; fi)"
echo ""

if [[ -z "$BRIDGE_ADAPTER" ]]; then
    echo "  Network (NAT with port forwarding):"
    echo "    - SSH: ssh -p 2222 admin@127.0.0.1"
    echo "    - HTTP: http://127.0.0.1:8080"
    echo "    - HTTPS: https://127.0.0.1:8443"
else
    echo "  Network (Bridged):"
    echo "    - Adapter: $BRIDGE_ADAPTER"
    echo "    - VM will get IP from your network's DHCP"
fi

echo ""
echo "  Next steps:"
echo "    1. Start the VM: VBoxManage startvm \"$VM_NAME\""
echo "    2. Boot from Arch ISO"
echo "    3. Clone the project: git clone <repo> ~/arch"
echo "    4. Run installation: cd ~/arch/src && ./install.sh"
echo ""

if [[ "$START_VM" == "true" ]]; then
    log "Starting VM..."
    VBoxManage startvm "$VM_NAME"
    success "VM started"
    echo ""
    echo "  The VM window should now be open."
    echo "  Wait for Arch ISO to boot, then run the installation."
fi

echo "================================================================"
