# VirtualBox Testing Guide

This guide covers how to test Arch Server v5.1 in VirtualBox before deploying to physical hardware.

## VM Configuration

### Required Settings

| Setting | Value | Location |
|---------|-------|----------|
| **EFI** | Enabled | Settings > System > Enable EFI |
| **RAM** | 4096 MB minimum | Settings > System > Base Memory |
| **Storage** | 30 GB+ (VDI, dynamic) | Settings > Storage |
| **Network** | Bridged Adapter (recommended) | Settings > Network |

### Optional Settings

| Setting | Value | Notes |
|---------|-------|-------|
| **TPM** | v2.0 | Settings > System > TPM (VirtualBox 7+ only) |
| **Secure Boot** | Disabled initially | Enable after key enrollment |
| **CPU** | 2+ cores | Settings > System > Processor |
| **Video** | 16 MB | Minimal for server |

## Network Configuration

### Option 1: Bridged Adapter (Recommended)

The VM gets an IP on the same network as the host. Best for testing SSH access.

- Settings > Network > Adapter 1 > Bridged Adapter
- Select your host's active network interface
- The VM will get its own IP via DHCP

### Option 2: NAT with Port Forwarding

The VM is behind NAT. Add port forwarding rules for access:

- Settings > Network > Adapter 1 > NAT
- Advanced > Port Forwarding:
  - SSH: Host Port 2222 > Guest Port 22
  - HTTP: Host Port 8080 > Guest Port 80
  - HTTPS: Host Port 8443 > Guest Port 443

Access with: `ssh -p 2222 admin@127.0.0.1`

### Option 3: Host-Only + NAT (Two adapters)

Best of both worlds - internet access and direct host communication:

- Adapter 1: NAT (internet access)
- Adapter 2: Host-Only Adapter (host-to-guest communication)

## Installation Steps

### 1. Create VM and attach Arch ISO

Download the latest Arch Linux ISO and attach it as a virtual optical disk.

### 2. Boot in EFI mode

Verify EFI is enabled in VM settings. The Arch ISO should show the UEFI boot menu.

### 3. Configure for VirtualBox

Use the basic config template with these adjustments:

```bash
# config.env adjustments for VirtualBox
TARGET_DISK="/dev/sda"          # VirtualBox uses sda (not nvme)
ENABLE_TPM_UNLOCK=false         # Unless VirtualBox 7+ with TPM enabled
ENABLE_SECURE_BOOT=false        # Disable for initial testing
STATIC_IP=""                    # Leave empty for DHCP in bridged mode
```

### 4. Run installation

```bash
# From the Arch ISO
cd /root/arch/src
./install.sh
```

The installer will automatically detect VirtualBox and apply compatibility adjustments.

### 5. Post-installation

After reboot:

```bash
# Check network
sudo /usr/local/bin/network-diagnostics.sh

# Deploy services
cd /root/arch
sudo ./scripts/deploy.sh
```

## Known Limitations

### Secure Boot

- VirtualBox has limited Secure Boot support
- Custom key enrollment may not work reliably
- Recommended: Test with Secure Boot disabled, enable on real hardware

### TPM 2.0

- Only available in VirtualBox 7.0+
- Must be explicitly enabled in VM settings
- PCR values may differ from physical hardware
- TPM auto-unlock testing is limited

### Performance

- Btrfs compression has higher CPU overhead in VM
- Disk I/O is slower than bare metal
- Consider `BTRFS_COMPRESSION="zstd:1"` for faster VM testing

### Networking

- Default interface name: `enp0s3` (NAT/Bridged) or `enp0s8` (Host-Only)
- DHCP may be slow on first boot (wait 10-15 seconds)
- Static IP recommended for consistent SSH access

## Troubleshooting

### VM does not boot after installation

1. Verify EFI is enabled in VM settings
2. Check boot order: Hard Disk should be first
3. Try: Settings > System > uncheck "Enable Secure Boot"
4. If stuck, boot from ISO and check EFI partition:
   ```bash
   mount /dev/sda1 /mnt
   ls /mnt/EFI/Linux/  # Should contain .efi files
   ```

### No network after boot

Run the network diagnostics script:

```bash
sudo /usr/local/bin/network-diagnostics.sh
```

Common fixes:
```bash
# Restart NetworkManager
sudo systemctl restart NetworkManager

# Manual DHCP
sudo nmcli device connect enp0s3

# Check interface exists
ip link show
```

### Cannot SSH from host

- **NAT mode**: Need port forwarding (see above)
- **Bridged mode**: Check VM IP with `ip addr` on VM console
- **Firewall**: Temporarily disable: `sudo systemctl stop nftables`

### LUKS password prompt not appearing

- VirtualBox sometimes has slow EFI boot
- Wait 10-20 seconds at black screen
- If nothing happens, force reset and try again
- Check VM console output for errors

## Testing Checklist

Use this checklist when testing in VirtualBox:

- [ ] VM boots in EFI mode
- [ ] Installation completes without errors
- [ ] LUKS password accepted at boot
- [ ] Network connectivity after boot
- [ ] SSH access from host
- [ ] Ansible deployment runs successfully
- [ ] Web server responds (if configured)
- [ ] Firewall rules applied correctly
- [ ] Health check passes: `sudo /usr/local/bin/health-check`

## Transitioning to Physical Hardware

When moving from VirtualBox to real hardware:

1. **Disk**: Change `TARGET_DISK` to your actual disk (e.g., `/dev/nvme0n1`)
2. **Secure Boot**: Enable `ENABLE_SECURE_BOOT=true`
3. **TPM**: Enable `ENABLE_TPM_UNLOCK=true`
4. **Network**: Configure `STATIC_IP` if needed
5. **Kernel**: Consider `KERNEL_TYPE="hardened"` for production
6. Re-run the installer on the target hardware
