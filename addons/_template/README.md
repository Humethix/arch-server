# [ADDON_NAME]

Beskrivelse af dette addon.

## Installation

1. Kopier addon til `addons/available/[ADDON_NAME]/`
2. Konfigurer `config.env`:
   ```bash
   cp config.env.example config.env
   # Rediger config.env med dine værdier
   ```
3. Installer addon:
   ```bash
   sudo ./addons/addon-manager.sh install [ADDON_NAME]
   ```

## Konfiguration

### Vigtige indstillinger i `config.env`:

- `PORT`: Port servicen lytter på (localhost only)
- `EXPOSE_EXTERNAL`: Sæt til `true` for ekstern adgang via Cloudflare Tunnel
- `SUBDOMAIN`: Subdomain for ekstern adgang
- `IMAGE_VERSION`: Container image version

## Brug

Service kører på: http://127.0.0.1:PORT

Hvis `EXPOSE_EXTERNAL=true`: https://SUBDOMAIN.humethix.dk

## Management

### Status
```bash
systemctl status [ADDON_NAME]
```

### Logs
```bash
journalctl -u [ADDON_NAME] -f
```

### Genstart
```bash
systemctl restart [ADDON_NAME]
```

## Afinstallation

Bevar data:
```bash
sudo ./addons/addon-manager.sh uninstall [ADDON_NAME]
```

Slet alt data:
```bash
sudo ./addons/addon-manager.sh uninstall [ADDON_NAME] --purge
```

## Data

Service data gemmes i: `/mnt/data/[ADDON_NAME]/`

Konfiguration gemmes i: `/etc/humethix/[ADDON_NAME]/`

Secrets gemmes i: `/etc/humethix/secrets/[ADDON_NAME]/`

## Backup

Dette addon er automatisk inkluderet i Humethix backup systemet.

## Support

For problemer med dette addon, tjek:
1. Service status: `systemctl status [ADDON_NAME]`
2. Logs: `journalctl -u [ADDON_NAME] -n 50`
3. Installation log: `/var/log/humethix/addon-[ADDON_NAME].log`
