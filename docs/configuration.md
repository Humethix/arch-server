# Configuration Reference

## config.env

The main configuration file for the installer.

### System Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `HOSTNAME` | `archserver` | System hostname |
| `USERNAME` | `admin` | Primary user account |
| `TIMEZONE` | `Europe/Copenhagen` | System timezone |
| `LOCALE` | `da_DK.UTF-8` | System locale |
| `KEYMAP` | `dk` | Console keymap |

### Kernel Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `KERNEL_TYPE` | `hardened` | Kernel variant (hardened/lts/default) |
| `USE_SYSTEMD_BOOT` | `true` | Use systemd-boot |
| `USE_UKI` | `true` | Use Unified Kernel Images |
| `ENABLE_SECURE_BOOT` | `true` | Prepare for Secure Boot |

### Encryption

| Variable | Default | Description |
|----------|---------|-------------|
| `LUKS_PASSWORD` | (generated) | Disk encryption password |
| `ENABLE_TPM_UNLOCK` | `true` | TPM auto-unlock |
| `TPM_USE_PIN` | `true` | Require PIN with TPM |

### Network

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_WIFI` | `true` | Configure WiFi |
| `WIFI_SSID` | - | WiFi network name |
| `WIFI_PASSWORD` | - | WiFi password |

### SSH

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_KEY_FILE` | `authorized_keys.pub` | SSH public key path |
| `SSH_GENERATE_IF_MISSING` | `true` | Auto-generate if missing |

### Disk

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_DISK` | - | Target disk (sda, nvme0n1) |
| `EFI_SIZE_MB` | `1024` | EFI partition size |
| `BTRFS_COMPRESSION` | `zstd:3` | Btrfs compression |

## Ansible Variables

See `src/ansible/inventory/hosts.yml` for Ansible-specific variables.
