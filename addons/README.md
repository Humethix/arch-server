# Humethix Addon System

Et modulært system til at tilføje services til Humethix Arch Server. Addon systemet gør det nemt at installere, administrere og vedligeholde forskellige services med ensartet sikkerhed og integration.

## Hurtig Start

### 1. Se tilgængelige addons
```bash
./addons/addon-manager.sh list
```

### 2. Installer et addon
```bash
# Eksempel med Uptime Kuma
cd addons/available/uptime-kuma
cp config.env.example config.env
# Rediger config.env om nødvendigt
cd ../../
sudo ./addon-manager.sh install uptime-kuma
```

### 3. Tjek status
```bash
./addons/addon-manager.sh status
```

## Kommandoer

### `addon-manager.sh list`
Viser alle tilgængelige addons med deres installationstatus:
- ✅ Kører (grøn)
- ⚠ Installeret men inaktiv (gul)  
- ❌ Ikke installeret (rød)

### `addon-manager.sh install [addon]`
Installerer et addon:
- Validerer addon struktur
- Opretter service user
- Installerer container
- Konfigurerer systemd service
- Registrerer backup og tunnel
- Starter service

### `addon-manager.sh uninstall [addon] [--purge]`
Afinstallerer et addon:
- Stopper og fjerner service
- Fjerner container og systemd unit
- Fjerner backup/tunnel registration
- `--purge`: Sletter også alle data

### `addon-manager.sh status`
Viser detaljeret status for installerede addons:
- Service status
- Resource usage
- Seneste logs

### `addon-manager.sh validate [addon]`
Validerer at et addon følger specifikationen:
- Tjekker påkrævede filer
- Verificerer struktur
- Sætter permissions

### `addon-manager.sh create [addon]`
Opretter nyt addon fra skabelon:
- Kopierer `_template` mappen
- Erstatter placeholders
- Sætter executable permissions

## Struktur

```
addons/
├── ADDON_SPEC.md              # Komplet specifikation
├── addon-manager.sh           # Management script
├── _template/                 # Skabelon for nye addons
│   ├── install.sh
│   ├── uninstall.sh
│   ├── config.env.example
│   ├── [addon-name].service
│   └── README.md
├── available/                 # Tilgængelige addons
│   └── uptime-kuma/          # Eksempel addon
│       ├── install.sh
│       ├── uninstall.sh
│       ├── config.env.example
│       ├── uptime-kuma.service
│       └── README.md
└── README.md                  # Denne fil
```

## Opret Nyt Addon

### 1. Brug skabelon
```bash
./addons/addon-manager.sh create min-service
```

### 2. Tilpas filer
Rediger filerne i `addons/available/min-service/`:

**config.env.example**:
```bash
# Container image
IMAGE="my-service"
IMAGE_VERSION="latest"

# Port
PORT=8080
CONTAINER_PORT=8080

# Ekstern adgang
EXPOSE_EXTERNAL=false
SUBDOMAIN="min-service"

# Resources
MEMORY_LIMIT="512m"
CPU_LIMIT="1.0"
```

**install.sh**: Tilpas container installation
**uninstall.sh**: Tilpas container fjernelse
**[service].service**: Tilpad Podman kommando
**README.md**: Dokumentation

### 3. Test addon
```bash
./addons/addon-manager.sh validate min-service
sudo ./addons/addon-manager.sh install min-service
```

## Sikkerhedsmodel

### Network Security
- Services binder KUN til localhost (127.0.0.1)
- Ekstern adgang kun via Cloudflare Tunnel
- Ingen åbne porte i firewall

### User Isolation
- Hver service kører som dedikeret system user
- Minimal permissions og capabilities
- Rootless containers hvor muligt

### Data Protection
- Data gemmes i krypteret `/mnt/data/[service]/`
- Secrets i `/etc/humethix/secrets/[service]/` (chmod 700)
- Automatisk backup via restic

### Container Security
```bash
# Security hardening i systemd units
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
```

## Integration

### Cloudflare Tunnel
Hvis `EXPOSE_EXTERNAL=true`:
```bash
# Automatisk registrering
echo "${SUBDOMAIN}.${DOMAIN} http://127.0.0.1:${PORT}" >> /etc/humethix/cloudflare-tunnels.conf
```

### Backup System
Alle addons registrerer automatisk deres data mapper:
```bash
echo "/mnt/data/[service]" >> /etc/humethix/backup-paths.conf
```

### Logging
- System logs: `journalctl -u [service]`
- Installation logs: `/var/log/humethix/addon-[service].log`
- Container logs: `sudo -u [service] podman logs [service]`

## Eksempler

### Uptime Kuma (Monitoring)
```bash
sudo ./addon-manager.sh install uptime-kuma
# Tilgængelig på http://127.0.0.1:3001
```

### Custom Web Service
```bash
./addon-manager.sh create my-web-app
# Rediger config.env med port 8080
sudo ./addon-manager.sh install my-web-app
```

### Database Service
```bash
./addon-manager.sh create postgres-db
# Konfigurer persistent data volumes
# Sæt EXPOSE_EXTERNAL=false (kun lokal adgang)
sudo ./addon-manager.sh install postgres-db
```

## Troubleshooting

### Service starter ikke
```bash
# Tjek status
systemctl status [service]

# Tjek logs
journalctl -u [service] -n 50

# Tjek container
sudo -u [service] podman logs [service]
```

### Port konflikt
```bash
# Tjek om port er i brug
ss -tlnp | grep :[PORT]

# Ændr port i config.env
# Geninstaller addon
```

### Permission fejl
```bash
# Tjek user permissions
id [service]

# Tjek mappe permissions
ls -la /mnt/data/[service]
ls -la /etc/humethix/secrets/[service]
```

### Container problemer
```bash
# Tjek container status
sudo -u [service] podman ps -a

# Genstart container
sudo -u [service] podman restart [service]

# Fjern og genskab
sudo -u [service] podman rm -f [service]
systemctl restart [service]
```

## Best Practices

### 1. Konfiguration
- Brug `config.env.example` som skabelon
- Undgå hardcoding af secrets
- Dokumenter alle konfigurationsmuligheder

### 2. Resources
- Sæt realistiske memory/CPU limits
- Overvåg resource usage
- Brug lightweight images hvor muligt

### 3. Sikkerhed
- Kør rootless når muligt
- Drop unødvendige capabilities
- Brug read-only filesystems

### 4. Backup
- Test backup og restore
- Dokumenter hvad der bliver backet op
- Overvej backup frekvens

### 5. Monitoring
- Opsæt health checks
- Monitor resource usage
- Sæt op notifikationer

## Avanceret

### Multi-Container Addons
For services med flere containers:
1. Brug docker-compose style i install.sh
2. Opret flere systemd units
3. Brug Podman pod netværk

### Custom Volumes
```bash
# Ekstra volumes i config.env
EXTRA_VOLUMES="/path/to/host:/path/to/container:Z"

# Brug i install.sh
for volume in $EXTRA_VOLUMES; do
    PODMAN_CMD+=" -v $volume"
done
```

### Environment Variables
```bash
# I config.env
ENV_VARS="VAR1=value1,VAR2=value2"

# I install.sh
IFS=',' read -ra ENV_ARRAY <<< "$ENV_VARS"
for env in "${ENV_ARRAY[@]}"; do
    PODMAN_CMD+=" -e $env"
done
```

## Bidrag

Nye addons skal:
1. Followe ADDON_SPEC.md
2. Være testet grundigt
3. Have god dokumentation
4. Være sikre som standard

Submit via pull request med:
- Addon i `available/` mappen
- Test resultater
- Dokumentation af use cases

## Support

For hjælp med addon systemet:
1. Læs ADDON_SPEC.md for tekniske detaljer
2. Tjek `addon-manager.sh --help`
3. Kig i eksisterende addons for inspiration
4. Brug `validate` kommando til at tjekke struktur

For specifikke addon problemer, se addon'ets README.md.
