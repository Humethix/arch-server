# Arch Server v5.1

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-v5.1-1793D1?logo=arch-linux)](https://archlinux.org)

**Complete plug-and-play secure server deployment for Arch Linux**

## ✨ Features

- 🔒 **LUKS2 Encryption** - Full disk encryption with Argon2id + TPM auto-unlock
- 🚀 **systemd-boot + UKI** - Modern bootloader with Unified Kernel Images
- 📁 **Btrfs Snapshots** - Automatic rollback on failed updates
- 🛡️ **Defense-in-Depth** - nftables + AppArmor + auditd
- 🌐 **Cloudflare Ready** - Firewall only allows Cloudflare IPs
- 📦 **Podman Containers** - Rootless container runtime
- ⚡ **Caddy Web Server** - Automatic HTTPS with HTTP/3

## 📋 Requirements

- UEFI-capable system
- 2GB+ RAM (4GB recommended)
- 20GB+ storage
- Internet connection

## 🚀 Quick Start

### 1. Prepare SSH Key (Recommended)

The installer automatically finds SSH keys in this order:
1. `authorized_keys.pub` in project root
2. Keys in `~/.ssh/id_*.pub` (ed25519, rsa, ecdsa)
3. Offers to generate new keys if none found

```bash
# Option 1: Copy to project root
cp ~/.ssh/id_ed25519.pub authorized_keys.pub

# Option 2: Let installer auto-discover (no action needed)
# The installer will find ~/.ssh/id_*.pub automatically
```

### 2. Setup Configuration

Boot from Arch ISO and run:

```bash
# Download project
curl -L https://github.com/humethix/arch-server/archive/main.tar.gz | tar xz
cd arch-server-main

# Choose configuration level
chmod +x src/config-setup.sh
./src/config-setup.sh

# Or manually edit configuration
nano src/config.env

# Run installer
chmod +x src/install.sh
./src/install.sh
```

### 3. Deploy Server (After Reboot)

```bash
sudo -i
cd /root/arch
./scripts/deploy.sh
```

### 4. Setup Cloudflare Tunnel

```bash
./scripts/setup-cloudflare.sh
```

### 5. Verify

```bash
/usr/local/bin/health-check
```

## 📁 Project Structure

```
arch-server/
├── src/                    # Source files
│   ├── install.sh          # Main installer
│   ├── config.env          # Configuration (generated)
│   ├── config.env.basic    # Basic configuration template
│   ├── config.env.advanced # Advanced configuration template
│   ├── config-setup.sh     # Interactive config setup
│   └── ansible/            # Ansible automation
│       ├── playbooks/
│       └── roles/
├── scripts/                # Utility scripts
│   ├── deploy.sh
│   ├── setup-cloudflare.sh
│   └── verify-deployment.sh
├── docs/                   # Documentation
├── templates/              # Config templates
├── tests/                  # Test suite
├── authorized_keys.pub     # SSH public key (gitignored)
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## 🔧 Configuration

### Quick Setup (Recommended)

Use the interactive configuration setup:

```bash
./src/config-setup.sh
```

Choose from:
- **Basic**: Essential settings only (perfect for new users)
- **Advanced**: Full configuration with all security options
- **Custom**: Start basic, add advanced options as needed

### Manual Configuration

Or edit configuration files manually:

- `src/config.env.basic` - Essential settings for quick deployment
- `src/config.env.advanced` - Complete configuration with all options

Copy your preferred template to `src/config.env`:

```bash
cp src/config.env.basic src/config.env  # For basic setup
# or
cp src/config.env.advanced src/config.env  # For advanced setup
```

### Essential Settings

Always configure these regardless of your chosen level:

```bash
# Required
HOSTNAME="your-server-name"
USERNAME="your-username"
TIMEZONE="Europe/Copenhagen"

# Passwords (leave empty for auto-generation)
ROOT_PASSWORD=""
USER_PASSWORD=""
LUKS_PASSWORD=""

# Optional but recommended
SSH_KEY_FILE="keys/authorized_keys.pub"  # Your SSH public key
DOMAIN="yourdomain.com"                  # For auto SSL
```

## 🛡️ Security Features

| Feature | Description |
|---------|-------------|
| **LUKS2** | AES-XTS-512 with Argon2id KDF |
| **Secure Boot** | Custom keys with sbctl |
| **Firewall** | nftables with Cloudflare-only mode |
| **SSH** | Key-based auth, rate limiting |
| **AppArmor** | Mandatory access control |
| **Auditd** | Security event logging |
| **Snapshots** | Btrfs snapshots with Snapper |

## 📦 Ansible Roles

| Role | Description |
|------|-------------|
| `base_hardening` | Sysctl, SSH, kernel modules |
| `container_runtime` | Podman with rootless support |
| `cloudflare` | Cloudflare IP allowlisting |
| `crowdsec` | Threat detection (AUR) |
| `security_stack` | nftables, AppArmor, auditd |
| `webserver` | Caddy web server |
| `monitoring` | htop, sysstat, journald, Prometheus Node Exporter |
| `safe_updates` | Snapper Btrfs snapshots |

## 💻 Development

```bash
# Setup development environment
pip install -r requirements.txt
pre-commit install

# Run linters
task lint

# Run tests
task test

# Build release
task build
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## 📖 Documentation

- [Installation Guide](docs/installation.md)
- [Configuration Reference](docs/configuration.md)
- [Deployment Guide](docs/deployment.md)
- [Security Guide](docs/security.md)

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## 📄 License

MIT License - Copyright (c) 2026 Mike Holmsted (Humethix)

See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [Arch Linux](https://archlinux.org)
- [Ansible](https://ansible.com)
- [Caddy](https://caddyserver.com)
- [Cloudflare](https://cloudflare.com)
