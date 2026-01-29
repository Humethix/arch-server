<#
.SYNOPSIS
    Creates a properly configured VirtualBox VM for Arch Server testing.

.DESCRIPTION
    This script automates VirtualBox VM creation with correct EFI, TPM,
    and network settings for testing Arch Server v5.1 installation.

.PARAMETER Name
    VM name (default: arch-server-test)

.PARAMETER IsoPath
    Path to Arch Linux ISO (required)

.PARAMETER RamMB
    RAM in MB (default: 4096)

.PARAMETER DiskGB
    Disk size in GB (default: 30)

.PARAMETER Cpus
    Number of CPUs (default: 2)

.PARAMETER BridgeAdapter
    Use bridged networking with this adapter name

.PARAMETER NoTpm
    Disable TPM 2.0

.PARAMETER NoEfi
    Use BIOS instead of EFI (not recommended)

.PARAMETER Start
    Start VM after creation

.PARAMETER Delete
    Delete existing VM with same name first

.EXAMPLE
    .\Setup-VirtualBoxVM.ps1 -IsoPath "C:\ISOs\archlinux.iso"

.EXAMPLE
    .\Setup-VirtualBoxVM.ps1 -IsoPath "C:\ISOs\archlinux.iso" -Name "test-vm" -Start

.EXAMPLE
    .\Setup-VirtualBoxVM.ps1 -IsoPath "C:\ISOs\archlinux.iso" -BridgeAdapter "Ethernet" -Start
#>

[CmdletBinding()]
param(
    [string]$Name = "arch-server-test",

    [Parameter(Mandatory=$true)]
    [string]$IsoPath,

    [int]$RamMB = 4096,
    [int]$DiskGB = 30,
    [int]$Cpus = 2,
    [string]$BridgeAdapter = "",
    [switch]$NoTpm,
    [switch]$NoEfi,
    [switch]$Start,
    [switch]$Delete
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$ErrorActionPreference = "Stop"

# Find VBoxManage
$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $VBoxManage)) {
    $VBoxManage = "${env:ProgramFiles}\Oracle\VirtualBox\VBoxManage.exe"
}
if (-not (Test-Path $VBoxManage)) {
    # Try to find in PATH
    $VBoxManage = (Get-Command VBoxManage -ErrorAction SilentlyContinue).Source
}

# ============================================================================
# FUNCTIONS
# ============================================================================

function Write-Log($msg) { Write-Host ">>> " -ForegroundColor Blue -NoNewline; Write-Host $msg }
function Write-Success($msg) { Write-Host "OK  " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn($msg) { Write-Host "!!  " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err($msg) { Write-Host "ERR " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }

function Invoke-VBox {
    param([string[]]$Arguments)
    # Run VBoxManage and capture output, ignoring stderr (progress output)
    $ErrorActionPreference = 'SilentlyContinue'
    $result = & $VBoxManage @Arguments 2>$null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    if ($exitCode -ne 0) {
        # Re-run to get error message
        $errOutput = & $VBoxManage @Arguments 2>&1 | Out-String
        throw "VBoxManage failed: $errOutput"
    }
    return $result
}

# ============================================================================
# BANNER
# ============================================================================

Write-Host ""
Write-Host "+--------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "|   VIRTUALBOX VM SETUP v5.1                                   |" -ForegroundColor Cyan
Write-Host "|   Creates a properly configured VM for Arch Server testing   |" -ForegroundColor Cyan
Write-Host "+--------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# VALIDATION
# ============================================================================

# Check VBoxManage
if (-not $VBoxManage -or -not (Test-Path $VBoxManage)) {
    Write-Err "VBoxManage not found! Install VirtualBox first."
}

$VbVersion = (Invoke-VBox @("--version")) -replace 'r.*',''
Write-Log "VirtualBox version: $VbVersion"

# Check version for TPM support
$VbMajor = [int]($VbVersion.Split('.')[0])
$EnableTpm = -not $NoTpm
$EnableEfi = -not $NoEfi

if ($VbMajor -lt 7 -and $EnableTpm) {
    Write-Warn "VirtualBox $VbVersion detected - TPM 2.0 requires version 7.0+"
    Write-Warn "Disabling TPM support"
    $EnableTpm = $false
}

# Check ISO
if (-not (Test-Path $IsoPath)) {
    Write-Err "ISO not found: $IsoPath"
}
Write-Success "ISO found: $IsoPath"

# Define paths early for cleanup
$vmFolder = Join-Path $env:USERPROFILE "VirtualBox VMs"
$vmPath = Join-Path $vmFolder $Name
$diskPath = Join-Path $vmPath "$Name.vdi"

# Check if VM already exists
$ErrorActionPreference = 'SilentlyContinue'
$existingVms = & $VBoxManage list vms 2>&1 | Out-String
$ErrorActionPreference = 'Stop'

if ($existingVms -match "`"$Name`"") {
    if ($Delete) {
        Write-Log "Deleting existing VM: $Name"
        $ErrorActionPreference = 'SilentlyContinue'
        $null = & $VBoxManage unregistervm $Name --delete 2>&1
        $ErrorActionPreference = 'Stop'
        Start-Sleep -Seconds 1
        Write-Success "Existing VM deleted"
    } else {
        Write-Err "VM '$Name' already exists! Use -Delete to remove it first."
    }
}

# Clean up any orphaned disk from VirtualBox media registry
if ($Delete) {
    $ErrorActionPreference = 'SilentlyContinue'
    $existingMedia = & $VBoxManage list hdds 2>&1 | Out-String
    $ErrorActionPreference = 'Stop'

    if ($existingMedia -match [regex]::Escape($diskPath)) {
        Write-Log "Removing orphaned disk from media registry..."
        $ErrorActionPreference = 'SilentlyContinue'
        $null = & $VBoxManage closemedium disk "$diskPath" --delete 2>&1
        $ErrorActionPreference = 'Stop'
        Start-Sleep -Seconds 1
        Write-Success "Orphaned disk removed from registry"
    }
}

# Also clean up any leftover VM folder
if (Test-Path $vmPath) {
    if ($Delete) {
        Write-Log "Removing leftover VM folder: $vmPath"
        Remove-Item -Recurse -Force $vmPath -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Success "Leftover files removed"
    } else {
        Write-Err "VM folder '$vmPath' exists! Use -Delete to remove it first."
    }
}

# ============================================================================
# CREATE VM
# ============================================================================

Write-Log "Creating VM: $Name"
Write-Host "  RAM: ${RamMB}MB"
Write-Host "  Disk: ${DiskGB}GB"
Write-Host "  CPUs: $Cpus"
Write-Host "  EFI: $EnableEfi"
Write-Host "  TPM: $EnableTpm"
Write-Host ""

# Get VM folder - parse directly from VBoxManage output
$sysProps = & $VBoxManage list systemproperties 2>$null
$vmFolderLine = $sysProps | Where-Object { $_ -match "Default machine folder:" }
if ($vmFolderLine) {
    $vmFolder = ($vmFolderLine -split ":\s*", 2)[1].Trim()
} else {
    # Fallback to default location
    $vmFolder = Join-Path $env:USERPROFILE "VirtualBox VMs"
}
$vmPath = Join-Path $vmFolder $Name
$diskPath = Join-Path $vmPath "$Name.vdi"

Write-Host "  VM folder: $vmFolder"

# Create VM
Invoke-VBox @("createvm", "--name", $Name, "--ostype", "ArchLinux_64", "--register")
Write-Success "VM created"

# Configure system settings
Write-Log "Configuring system settings..."

# Basic settings
Invoke-VBox @(
    "modifyvm", $Name,
    "--memory", $RamMB,
    "--cpus", $Cpus,
    "--vram", "16",
    "--graphicscontroller", "vmsvga",
    "--audio-driver", "none",
    "--boot1", "dvd",
    "--boot2", "disk",
    "--boot3", "none",
    "--boot4", "none"
)

# EFI settings
if ($EnableEfi) {
    Invoke-VBox @("modifyvm", $Name, "--firmware", "efi64")
    Write-Success "EFI firmware enabled"
} else {
    Write-Warn "Using BIOS mode - Secure Boot and UKI will not work!"
}

# TPM settings
if ($EnableTpm) {
    Invoke-VBox @("modifyvm", $Name, "--tpm-type", "2.0")
    Write-Success "TPM 2.0 enabled"
}

# Network settings
Write-Log "Configuring network..."
if ($BridgeAdapter) {
    Invoke-VBox @("modifyvm", $Name, "--nic1", "bridged", "--bridgeadapter1", $BridgeAdapter)
    Write-Success "Bridged networking: $BridgeAdapter"
} else {
    Invoke-VBox @(
        "modifyvm", $Name,
        "--nic1", "nat",
        "--natpf1", "SSH,tcp,,2222,,22",
        "--natpf1", "HTTP,tcp,,8080,,80",
        "--natpf1", "HTTPS,tcp,,8443,,443"
    )
    Write-Success "NAT networking with port forwarding (SSH:2222, HTTP:8080, HTTPS:8443)"
}

# Create storage controller
Write-Log "Creating storage..."

Invoke-VBox @(
    "storagectl", $Name,
    "--name", "SATA",
    "--add", "sata",
    "--controller", "IntelAhci",
    "--portcount", "2"
)

# Create virtual disk
$diskSizeMB = $DiskGB * 1024

# Ensure VM folder exists (VBoxManage doesn't create it)
if (-not (Test-Path $vmPath)) {
    New-Item -ItemType Directory -Path $vmPath -Force | Out-Null
}

$ErrorActionPreference = 'SilentlyContinue'
$null = & $VBoxManage createmedium disk --filename "$diskPath" --size $diskSizeMB --format VDI --variant Standard 2>&1
$diskExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($diskExitCode -ne 0) {
    Write-Err "Failed to create virtual disk at: $diskPath"
}
Write-Success "Virtual disk created: ${DiskGB}GB"

# Attach disk
$ErrorActionPreference = 'SilentlyContinue'
$null = & $VBoxManage storageattach $Name --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$diskPath" 2>&1
$attachExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($attachExitCode -ne 0) {
    Write-Err "Failed to attach disk"
}
Write-Success "Disk attached"

# Attach ISO
$ErrorActionPreference = 'SilentlyContinue'
$null = & $VBoxManage storageattach $Name --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$IsoPath" 2>&1
$isoExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($isoExitCode -ne 0) {
    Write-Err "Failed to attach ISO"
}
Write-Success "ISO attached"

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  VM CREATED SUCCESSFULLY" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  VM Name: $Name"
Write-Host "  VM Path: $vmPath"
Write-Host ""
Write-Host "  Settings:"
Write-Host "    - RAM: ${RamMB}MB"
Write-Host "    - Disk: ${DiskGB}GB ($diskPath)"
Write-Host "    - CPUs: $Cpus"
Write-Host "    - Firmware: $(if ($EnableEfi) { 'EFI' } else { 'BIOS' })"
Write-Host "    - TPM 2.0: $(if ($EnableTpm) { 'Enabled' } else { 'Disabled' })"
Write-Host ""

if (-not $BridgeAdapter) {
    Write-Host "  Network (NAT with port forwarding):"
    Write-Host "    - SSH: ssh -p 2222 admin@127.0.0.1"
    Write-Host "    - HTTP: http://127.0.0.1:8080"
    Write-Host "    - HTTPS: https://127.0.0.1:8443"
} else {
    Write-Host "  Network (Bridged):"
    Write-Host "    - Adapter: $BridgeAdapter"
    Write-Host "    - VM will get IP from your network's DHCP"
}

Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Start the VM: VBoxManage startvm `"$Name`""
Write-Host "    2. Boot from Arch ISO"
Write-Host "    3. Clone the project: git clone <repo> ~/arch"
Write-Host "    4. Run installation: cd ~/arch/src && ./install.sh"
Write-Host ""

if ($Start) {
    Write-Log "Starting VM..."
    Invoke-VBox @("startvm", $Name)
    Write-Success "VM started"
    Write-Host ""
    Write-Host "  The VM window should now be open."
    Write-Host "  Wait for Arch ISO to boot, then run the installation."
}

Write-Host "================================================================" -ForegroundColor Green
