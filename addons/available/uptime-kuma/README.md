# Uptime Kuma

Uptime Kuma er et fancy self-hosted monitoring tool. Det hjælper dig med at overvåge dine websites, APIs og services.

## Installation

1. Konfigurer `config.env`:
   ```bash
   cp config.env.example config.env
   # Rediger config.env om nødvendigt
   ```
2. Installer addon:
   ```bash
   sudo ./addons/addon-manager.sh install uptime-kuma
   ```

## Konfiguration

### Vigtige indstillinger i `config.env`:

- `PORT`: Port Uptime Kuma lytter på (standard: 3001)
- `EXPOSE_EXTERNAL`: Sæt til `true` for ekstern adgang via Cloudflare Tunnel
- `SUBDOMAIN`: Subdomain for ekstern adgang (standard: "status")
- `MEMORY_LIMIT`: Memory limit for container (standard: "512m")

## Første gangs setup

1. Besøg http://127.0.0.1:3001 efter installation
2. Opret admin konto
3. Tilføj dine monitors (websites, APIs, services)
4. Konfigurer notifikationer om nødvendigt

## Brug

### Lokal adgang
http://127.0.0.1:3001

### Ekstern adgang (hvis EXPOSE_EXTERNAL=true)
https://status.humethix.dk

## Management

### Status
```bash
systemctl status uptime-kuma
```

### Logs
```bash
journalctl -u uptime-kuma -f
```

### Genstart
```bash
systemctl restart uptime-kuma
```

### Container info
```bash
sudo -u uptime-kuma podman ps
sudo -u uptime-kuma podman logs uptime-kuma
```

## Afinstallation

Bevar data:
```bash
sudo ./addons/addon-manager.sh uninstall uptime-kuma
```

Slet alt data:
```bash
sudo ./addons/addon-manager.sh uninstall uptime-kuma --purge
```

## Data

- **Service data**: `/mnt/data/uptime-kuma/`
- **Konfiguration**: `/etc/humethix/uptime-kuma/`
- **Secrets**: `/etc/humethix/secrets/uptime-kuma/`

Uptime Kuma data inkluderer:
- Monitor konfigurationer
- Status historik
- Notifikation settings
- Bruger accounts

## Backup

Dette addon er automatisk inkluderet i Humethix backup systemet. Alle monitor data og konfigurationer bliver backet op.

## Features

- **Monitoring**: HTTP(s), TCP, ICMP, DNS, Push, Steam Game Server, etc.
- **Notifications**: Telegram, Discord, Gotify, Slack, Email, etc.
- **Status Pages**: Offentlige status sider
- **Multi-language**: Dansk, English, og mange flere
- **Docker/Podman**: Container-baseret deployment
- **Lightweight**: Minimal resource usage

## Tips

1. **Monitor dine Humethix services**: Tilføj monitors for dine andre addons
2. **Status page**: Brug den indbyggede status page funktion
3. **Notifikationer**: Opsæt notifikationer for at få alerts
4. **Backup**: Data bliver automatisk backet op af Humethix

## Support

For problemer med Uptime Kuma:

1. **Service status**: `systemctl status uptime-kuma`
2. **Logs**: `journalctl -u uptime-kuma -n 50`
3. **Container logs**: `sudo -u uptime-kuma podman logs uptime-kuma`
4. **Installation log**: `/var/log/humethix/addon-uptime-kuma.log`

For Uptime Kuma specifikke problemer, se den officielle dokumentation: https://github.com/louislam/uptime-kuma/wiki
