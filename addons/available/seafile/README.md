# Seafile

Seafile er en self-hosted file sync og share platform med enterprise-grade features. Det giver dig fuld kontrol over dine filer med sikkerhed, sync og collaboration funktioner.

## ⚠️ VIGTIGT - Storage Krav

Seafile kræver **dedikeret storage** til filer og biblioteker:

- **Minimum**: 50GB storage
- **Anbefalet**: 200GB+ for seriøs brug
- **Format**: Storage device vil blive formateret med ext4
- **Placering**: Dedicated mount point på `/mnt/seafile-storage`

## Installation

### 1. Forbered Storage Device

Identificer dit storage device:
```bash
# List available devices
lsblk
# F.eks. /dev/sdc1, /dev/nvme0n1p2, etc.
```

### 2. Konfigurer Seafile

```bash
cd addons/available/seafile
cp config.env.example config.env
```

**VIGTIGT - Rediger config.env:**
```bash
# PÅKRÆVET - Vælg dit storage device
STORAGE_DEVICE="/dev/sdc1"  # ÆNDR DENNE!

# Admin email
ADMIN_EMAIL="admin@humethix.dk"

# Minimum storage størrelse
MIN_STORAGE_GB=50

# Valgfrit - port settings
WEB_PORT=8080
FILE_SERVER_PORT=8082
EXPOSE_EXTERNAL=false  # Sæt til true for ekstern adgang
SUBDOMAIN="files"
```

### 3. Installer

```bash
sudo ./addons/addon-manager.sh install seafile
```

**Under installationen vil du blive spurgt:**
1. Bekræftelse af storage device
2. Bekræftelse af formatering (skriv 'JA' for at bekræfte)
3. Vent på installation (kan tage 5-10 minutter)

## Storage Struktur

Efter installation vil din storage blive organiseret således:

```
/mnt/seafile-storage/
├── seafile-data/      # User filer og biblioteker
├── ccnet/            # P2P netværk data
├── conf/             # Seafile konfiguration
├── seafile/          # Seafile server data
└── seahub-data/      # Web interface data
```

## Første Gangs Setup

1. Besøg http://127.0.0.1:8080 efter installation
2. Login med admin credentials vist i installationen
3. Konfigurer system settings
4. Opret biblioteker og brugere
5. Download Seafile clients til sync

## Brug

### Lokal adgang
http://127.0.0.1:8080

### Ekstern adgang (hvis EXPOSE_EXTERNAL=true)
https://files.humethix.dk

### Seafile Clients
Download Seafile clients til:
- **Desktop**: Windows, macOS, Linux
- **Mobile**: iOS, Android
- **CLI**: Command line sync

## Management

### Status
```bash
systemctl status seafile
```

### Logs
```bash
# Service logs
journalctl -u seafile -f

# Container logs
sudo -u seafile podman logs seafile
sudo -u seafile podman logs seafile-db
```

### Container status
```bash
sudo -u seafile podman-compose -f /etc/humethix/seafile/docker-compose.yml ps
```

### Genstart
```bash
systemctl restart seafile
```

## Storage Management

### Tjek storage usage
```bash
# Overall usage
df -h /mnt/seafile-storage

# Directory sizes
du -sh /mnt/seafile-storage/*
```

### Udvid storage
Hvis du løber tør for plads:
1. Stop seafile: `sudo systemctl stop seafile`
2. Backup data: `sudo rsync -av /mnt/seafile-storage/ /backup/location/`
3. Udvid partition (via GParted eller kommando linje)
4. Resize filesystem: `sudo resize2fs /dev/your-device`
5. Start seafile: `sudo systemctl start seafile`

### Backup af storage
```bash
# Backup til ekstern location
sudo rsync -av --progress /mnt/seafile-storage/ /backup/seafile-$(date +%Y%m%d)/
```

## Features

### File Sync & Share
- **Real-time sync**: Automatisk synkronisering på tværs af devices
- **File versioning**: Historik af filændringer
- **Selective sync**: Vælg hvilke mapper der skal synces
- **Offline access**: Arbejd offline, sync når online

### Collaboration
- **File sharing**: Del filer og mapper med links
- **Permission control**: Læse/skrive rettigheder
- **Group libraries**: Fælles biblioteker for teams
- **Comments**: Kommentarer på filer

### Security
- **End-to-end encryption**: Krypteret filoverførsel
- **Two-factor authentication**: 2FA support
- **Virus scanning**: Integreret virus scanning
- **Audit logs**: Log af alle aktiviteter

### Enterprise Features
- **LDAP/AD integration**: Enterprise authentication
- **Office Online**: Edit Office filer i browser
- **File preview**: Preview af PDF, billeder, video
- **Mobile apps**: iOS og Android apps

## Performance Tuning

### For store biblioteker (>100k filer)
```bash
# I config.env
MAX_UPLOAD_SIZE="500"  # MB
MAX_NUMBER_OF_FILES="50000"
SEAFILE_MEMORY_LIMIT="2g"  # Mere memory
ENABLE_FILE_HISTORY="false"  # Deaktiver hvis ikke nødvendigt
```

### Database optimization
```bash
# Tjek database status
sudo -u seafile podman exec seafile-db mysql -u root -p -e "SHOW PROCESSLIST;"

# Optimize database
sudo -u seafile podman exec seafile-db mysql -u root -p -e "OPTIMIZE TABLE seafile_db.*;"
```

## Afinstallation

### Bevar data
```bash
sudo ./addons/addon-manager.sh uninstall seafile
```

### Slet alt data
```bash
sudo ./addons/addon-manager.sh uninstall seafile --purge
```

**VIGTIGT**: Selv med --purge vil storage device IKKE blive formateret igen. Data slettes, men filesystem bevares.

## Troubleshooting

### Storage problemer
```bash
# Tjek mount
findmnt /mnt/seafile-storage

# Tjek disk health
sudo fsck -f /dev/your-storage-device

# Tjek permissions
ls -la /mnt/seafile-storage
```

### Container problemer
```bash
# Genbuild containers
sudo -u seafile podman-compose -f /etc/humethix/seafile/docker-compose.yml down
sudo -u seafile podman-compose -f /etc/humethix/seafile/docker-compose.yml up -d --force-recreate
```

### Sync problemer
```bash
# Tjek sync status
sudo -u seafile podman logs seafile | grep -i sync

# Genstart sync service
sudo -u seafile podman exec seafile seafile-controller restart
```

### Database problemer
```bash
# Tjek database connection
sudo -u seafile podman exec seafile-db mysql -u root -p -e "SELECT 1;"

# Repair database
sudo -u seafile podman exec seafile-db mysqlcheck -u root -p --repair seafile_db
```

## Backup Strategy

### Automatisk backup (Humethix)
Storage mappen `/mnt/seafile-storage` er automatisk inkluderet i Humethix backup systemet.

### Manuel backup
```bash
# Full backup script
#!/bin/bash
BACKUP_DIR="/backup/seafile-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup storage
sudo rsync -av --progress /mnt/seafile-storage/ "$BACKUP_DIR/storage/"

# Backup database
sudo -u seafile podman exec seafile-db mysqldump -u root -p --all-databases > "$BACKUP_DIR/database.sql"

echo "Backup completed: $BACKUP_DIR"
```

## Migration

### Fra andre cloud storage
1. Eksporter filer fra eksisterende system
2. Import til Seafile via web interface eller CLI
3. Opsæt sync clients for brugere

### Til ny server
1. Stop Seafile
2. Backup storage device
3. Installer på ny server med samme storage device
4. Restore data

## Integration

### LDAP/AD
```bash
# I config.env
LDAP_SERVER="ldap://your-server.com"
LDAP_BASE_DN="dc=company,dc=com"
LDAP_USER_DN="ou=users,dc=company,dc=com"
LDAP_BIND_DN="cn=admin,dc=company,dc=com"
LDAP_BIND_PASSWORD="your-password"
```

### Email notifikationer
```bash
# I config.env
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"
SMTP_TLS="true"
```

## Support

For Seafile specifikke problemer:
- [Officiel dokumentation](https://manual.seafile.com/)
- [GitHub Issues](https://github.com/haiwen/seafile/issues)
- [Seafile Forum](https://forum.seafile.com/)

For Humethix addon problemer:
1. Service status: `systemctl status seafile`
2. Logs: `journalctl -u seafile -n 100`
3. Storage: `df -h /mnt/seafile-storage`
4. Installation log: `/var/log/humethix/addon-seafile.log`
