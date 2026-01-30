# Immich

Immich er et self-hosted photo og video backup solution med avancerede features som AI-drevet object detection, face recognition og automatisk organisering.

## ⚠️ VIGTIGT - Storage Krav

Immich kræver **dedikeret storage** til billeder og video:

- **Minimum**: 100GB storage
- **Anbefalet**: 500GB+ for seriøs brug
- **Format**: Storage device vil blive formateret med ext4
- **Placering**: Dedicated mount point på `/mnt/immich-storage`

## Installation

### 1. Forbered Storage Device

Identificer dit storage device:
```bash
# List available devices
lsblk
# F.eks. /dev/sdb1, /dev/nvme0n1p1, etc.
```

### 2. Konfigurer Immich

```bash
cd addons/available/immich
cp config.env.example config.env
```

**VIGTIGT - Rediger config.env:**
```bash
# PÅKRÆVET - Vælg dit storage device
STORAGE_DEVICE="/dev/sdb1"  # ÆNDR DENNE!

# Minimum storage størrelse
MIN_STORAGE_GB=100

# Valgfrit - port settings
WEB_PORT=2283
EXPOSE_EXTERNAL=false  # Sæt til true for ekstern adgang
SUBDOMAIN="photos"
```

### 3. Installer

```bash
sudo ./addons/addon-manager.sh install immich
```

**Under installationen vil du blive spurgt:**
1. Bekræftelse af storage device
2. Bekræftelse af formatering (skriv 'JA' for at bekræfte)
3. Vent på installation (kan tage 5-10 minutter)

## Storage Struktur

Efter installation vil din storage blive organiseret således:

```
/mnt/immich-storage/
├── library/          # Importerede billeder/videoer
├── uploads/          # Uploadede filer
├── thumbnails/       # Genererede thumbnails
└── profile/          # Bruger profiler
```

## Første Gangs Setup

1. Besøg http://127.0.0.1:2283 efter installation
2. Opret admin konto
3. Konfigurer library path til `/mnt/immich-storage/library`
4. Upload dine første billeder

## Brug

### Lokal adgang
http://127.0.0.1:2283

### Ekstern adgang (hvis EXPOSE_EXTERNAL=true)
https://photos.humethix.dk

### Upload billeder
```bash
# Kopier billeder til library
sudo -u immich cp /path/to/photos/* /mnt/immich-storage/library/

# Eller brug web interface til upload
```

## Management

### Status
```bash
systemctl status immich
```

### Logs
```bash
# Service logs
journalctl -u immich -f

# Container logs
sudo -u immich podman logs immich_server
sudo -u immich podman logs immich_machine_learning
```

### Container status
```bash
sudo -u immich podman-compose -f /etc/humethix/immich/docker-compose.yml ps
```

### Genstart
```bash
systemctl restart immich
```

## Storage Management

### Tjek storage usage
```bash
# Overall usage
df -h /mnt/immich-storage

# Directory sizes
du -sh /mnt/immich-storage/*
```

### Udvid storage
Hvis du løber tør for plads:
1. Stop immich: `sudo systemctl stop immich`
2. Backup data: `sudo rsync -av /mnt/immich-storage/ /backup/location/`
3. Udvid partition (via GParted eller kommando linje)
4. Resize filesystem: `sudo resize2fs /dev/your-device`
5. Start immich: `sudo systemctl start immich`

### Backup af storage
```bash
# Backup til ekstern location
sudo rsync -av --progress /mnt/immich-storage/ /backup/immich-$(date +%Y%m%d)/
```

## Features

### AI Features
- **Object Detection**: Automatisk genkendelse af objekter
- **Face Recognition**: Genkendelse og gruppering af ansigter
- **Smart Search**: Søg efter "hund", "strand", "bil" etc.

### Organisering
- **Albums**: Organiser billeder i albums
- **Timeline**: Kronologisk visning
- **Map View**: Baseret på GPS metadata
- **Duplicates**: Find duplikat billeder

### Sharing
- **Public Sharing**: Del albums med offentlige links
- **Partner Sharing**: Del med specifikke brugere
- **Mobile App**: iOS og Android apps

## Performance Tuning

### For store biblioteker (>100k billeder)
```bash
# I config.env
THUMBNAIL_CONCURRENCY="4"  # Øg for hurtigere generation
SERVER_MEMORY_LIMIT="4g"   # Mere memory til server
ENABLE_MACHINE_LEARNING="false"  # Deaktiver hvis ikke nødvendigt
```

### Network optimization
```bash
# Tjek network performance
curl -w "@curl-format.txt" -o /dev/null -s "http://127.0.0.1:2283"
```

## Afinstallation

### Bevar data
```bash
sudo ./addons/addon-manager.sh uninstall immich
```

### Slet alt data
```bash
sudo ./addons/addon-manager.sh uninstall immich --purge
```

**VIGTIGT**: Selv med --purge vil storage device IKKE blive formateret igen. Data slettes, men filesystem bevares.

## Troubleshooting

### Storage problemer
```bash
# Tjek mount
findmnt /mnt/immich-storage

# Tjek disk health
sudo fsck -f /dev/your-storage-device

# Tjek permissions
ls -la /mnt/immich-storage
```

### Container problemer
```bash
# Genbuild containers
sudo -u immich podman-compose -f /etc/humethix/immich/docker-compose.yml down
sudo -u immich podman-compose -f /etc/humethix/immich/docker-compose.yml up -d --force-recreate
```

### Performance problemer
```bash
# Tjek resource usage
sudo -u immich podman stats

# Tjek disk I/O
iotop -o
```

### Database problemer
```bash
# Tjek database status
sudo -u immich podman exec immich_postgres psql -U postgres -d immich -c "SELECT COUNT(*) FROM assets;"
```

## Backup Strategy

### Automatisk backup (Humethix)
Storage mappen `/mnt/immich-storage` er automatisk inkluderet i Humethix backup systemet.

### Manuel backup
```bash
# Full backup script
#!/bin/bash
BACKUP_DIR="/backup/immich-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup storage
sudo rsync -av --progress /mnt/immich-storage/ "$BACKUP_DIR/storage/"

# Backup database
sudo -u immich podman exec immich_postgres pg_dump -U postgres immich > "$BACKUP_DIR/database.sql"

echo "Backup completed: $BACKUP_DIR"
```

## Migration

### Fra andre photo managers
1. Eksporter billeder fra eksisterende system
2. Kopier til `/mnt/immich-storage/library/`
3. Start Immich og lad den scanne biblioteket
4. Import metadata hvis muligt

### Til ny server
1. Stop Immich
2. Backup storage device
3. Installer på ny server med samme storage device
4. Restore data

## Support

For Immich specifikke problemer:
- [Officiel dokumentation](https://immich.app/docs)
- [GitHub Issues](https://github.com/immich-app/immich/issues)

For Humethix addon problemer:
1. Service status: `systemctl status immich`
2. Logs: `journalctl -u immich -n 100`
3. Storage: `df -h /mnt/immich-storage`
4. Installation log: `/var/log/humethix/addon-immich.log`
