# Humethix Addon Specification v1.0

## Formål

Dette dokument definerer standarden for addons til Humethix Arch Server systemet. Det giver både mennesker og AI'er nok information til at skabe funktionelle, sikre og velintegrerede services.

## Systemkontekst

### Base System Specifikationer

| Komponent | Specifikation |
|-----------|---------------|
| OS | Arch Linux (minimal, hardened) |
| Init | systemd |
| Kernel | linux-hardened |
| Disk encryption | LUKS2 på alle datapartitioner |
| Firewall | nftables (default deny, kun localhost services) |
| Container runtime | Podman (rootless foretrukket) |
| Ekstern adgang | Cloudflare Tunnel (ingen åbne porte) |
| Backup | restic til Backblaze B2 |
| Service users | Dedikeret bruger per service |

### Mappestruktur

```
/
├── etc/
│   └── humethix/              # Projektets konfigurationsfiler
│       ├── secrets/           # Service secrets (chmod 600)
│       └── backup-paths.conf  # Liste af stier til backup
├── mnt/
│   └── data/                  # LUKS2 krypteret data-partition
│       └── [service-navn]/    # Persistent data per service
├── opt/
│   └── humethix/              # Installerede scripts og services
└── home/
    └── [service-users]/       # Rootless container home dirs
```

### Sikkerhedsmodel

- **Netværk**: Services binder KUN til localhost. Ekstern adgang via Cloudflare Tunnel.
- **Brugere**: Hver service kører som dedikeret bruger med minimale rettigheder.
- **Secrets**: Gemmes i `/etc/humethix/secrets/[service]/` med restriktive permissions.
- **Containers**: Rootless Podman foretrækkes. Privileged mode kun hvis absolut nødvendigt (og skal dokumenteres hvorfor).

## Addon struktur

Et addon SKAL indeholde:

```
[addon-navn]/
├── install.sh              # Installation script (påkrævet)
├── uninstall.sh            # Afinstallation script (påkrævet)
├── config.env.example      # Konfigurationsskabelon (påkrævet)
├── [service].service       # systemd unit template (påkrævet)
└── README.md               # Dokumentation (påkrævet)
```

Et addon KAN indeholde:
- `docker-compose.yml` - For multi-container setups
- `pre-install.sh` - Scripts der køres før installation
- `post-install.sh` - Scripts der køres efter installation
- `templates/` - Konfigurationsskabeloner
- `files/` - Statiske filer der skal kopieres

## Krav til install.sh

### Grundlæggende krav
- Skal være idempotent (kan køres flere gange uden fejl)
- Skal bruge `set -euo pipefail`
- Skal have klare fejlbeskeder og korrekte exit codes
- Skal dokumentere hvad der sker undervejs

### Påkrævede funktioner
1. **Service user creation**
   ```bash
   # Opret system user hvis ikke eksisterende
   if ! id "$SERVICE_USER" &>/dev/null; then
       useradd --system --shell /usr/bin/nologin --create-home "$SERVICE_USER"
   fi
   ```

2. **Directory creation**
   ```bash
   mkdir -p "$DATA_DIR" "$CONFIG_DIR" "$SECRETS_DIR"
   chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
   chmod 750 "$DATA_DIR"
   chmod 700 "$SECRETS_DIR"
   ```

3. **Configuration loading**
   ```bash
   if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
       source "${SCRIPT_DIR}/config.env"
   else
       echo "FEJL: config.env ikke fundet. Kopiér config.env.example til config.env"
       exit 1
   fi
   ```

4. **Systemd service installation**
   ```bash
   cp "${SCRIPT_DIR}/${ADDON_NAME}.service" "/etc/systemd/system/"
   systemctl daemon-reload
   systemctl enable "$ADDON_NAME"
   ```

5. **Backup registration**
   ```bash
   echo "$DATA_DIR" >> /etc/humethix/backup-paths.conf
   sort -u /etc/humethix/backup-paths.conf -o /etc/humethix/backup-paths.conf
   ```

6. **Cloudflare Tunnel registration** (hvis `EXPOSE_EXTERNAL=true`)
   ```bash
   if [[ "${EXPOSE_EXTERNAL:-false}" == "true" ]]; then
       # Implementér tunnel registration
   fi
   ```

### Container installation
Brug rootless Podman:
```bash
sudo -u "$SERVICE_USER" podman pull "${IMAGE}:${IMAGE_VERSION}"
```

## Krav til uninstall.sh

### Grundlæggende krav
- Skal acceptere `--purge` flag for at slette data
- Skal IKKE slette brugerdata som standard
- Skal rydde op i alle systemregistreringer

### Påkrævede funktioner
1. **Service stop og disable**
   ```bash
   systemctl stop "$ADDON_NAME" 2>/dev/null || true
   systemctl disable "$ADDON_NAME" 2>/dev/null || true
   ```

2. **Systemd unit fjernelse**
   ```bash
   rm -f "/etc/systemd/system/${ADDON_NAME}.service"
   systemctl daemon-reload
   ```

3. **Backup deregistration**
   ```bash
   sed -i "\|/mnt/data/${ADDON_NAME}|d" /etc/humethix/backup-paths.conf 2>/dev/null || true
   ```

4. **Container fjernelse**
   ```bash
   sudo -u "$ADDON_NAME" podman rm -f "$ADDON_NAME" 2>/dev/null || true
   ```

5. **Data fjernelse (kun med --purge)**
   ```bash
   if [[ "$PURGE" == "true" ]]; then
       rm -rf "/mnt/data/${ADDON_NAME}"
       userdel -r "$ADDON_NAME" 2>/dev/null || true
   fi
   ```

## Krav til config.env.example

### Struktur
```bash
# =============================================================================
# [ADDON_NAME] Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# PÅKRÆVET - Disse SKAL ændres
# -----------------------------------------------------------------------------

# Ingen påkrævede ændringer for dette addon
# (eller list specifikke påkrævede ændringer her)

# -----------------------------------------------------------------------------
# VALGFRIT - Kan ændres efter behov
# -----------------------------------------------------------------------------

# Port servicen lytter på (kun localhost)
PORT=8080

# Eksponér via Cloudflare Tunnel? (true/false)
EXPOSE_EXTERNAL=false

# Subdomain hvis eksponeret (f.eks. "app" -> app.humethix.dk)
SUBDOMAIN="[addon-name]"

# Container image version
IMAGE_VERSION="latest"

# Ressource limits
MEMORY_LIMIT="512m"
CPU_LIMIT="1.0"
```

### Krav
- Alle konfigurerbare værdier skal have defaults
- Kommentarer skal forklare hver værdi
- Tydeligt markeret hvilke værdier der SKAL ændres vs kan ændres
- Ingen hemmeligheder må hardcodes

## Integration hooks

### Cloudflare Tunnel Integration
Hvis `EXPOSE_EXTERNAL=true` skal addon registrere sig i tunnel systemet:

```bash
# Tilføj til /etc/humethix/cloudflare-tunnels.conf
echo "${SUBDOMAIN}.${DOMAIN} http://127.0.0.1:${PORT}" >> /etc/humethix/cloudflare-tunnels.conf
```

### Backup Integration
Alle data mapper skal registreres til backup:

```bash
# Tilføj til /etc/humethix/backup-paths.conf
echo "/mnt/data/${ADDON_NAME}" >> /etc/humethix/backup-paths.conf
```

### Firewall Integration
Normalt ikke nødvendigt da services binder til localhost, men hvis krævet:

```bash
# Tilføj til /etc/nftables.d/humethix-services.nft
# (kun for services der skal være tilgængelige lokalt)
```

## Sikkerhedskrav

### Container Security
- Containers skal køre rootless medmindre umuligt
- Brug `--read-only` filesystem hvor muligt
- Drop alle unødvendige capabilities
- Brug minimale images (alpine/distroless)

### Secrets Management
- Secrets må aldrig hardcodes i scripts
- Gem secrets i `/etc/humethix/secrets/[service]/`
- Sæt permissions til `600` (owner read-only)
- Brug environment variables i containers

### Network Security
- Services binder KUN til 127.0.0.1
- Ingen åbne porte i firewall
- Ekstern adgang kun via Cloudflare Tunnel

### File Permissions
```bash
# Data mapper
chmod 750 /mnt/data/[service]
chown [service]:[service] /mnt/data/[service]

# Secrets mapper
chmod 700 /etc/humethix/secrets/[service]
chown root:root /etc/humethix/secrets/[service]
```

## systemd Service Template

### Grundlæggende struktur
```ini
[Unit]
Description=[ADDON_NAME] Service (Humethix)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=[addon-name]
Group=[addon-name]
WorkingDirectory=/home/[addon-name]

# Podman rootless container
ExecStart=/usr/bin/podman run \
    --name [addon-name] \
    --rm \
    --network slirp4netns:port_handler=slirp4netns \
    -p 127.0.0.1:${PORT}:${CONTAINER_PORT} \
    -v /mnt/data/[addon-name]:/data:Z \
    --memory ${MEMORY_LIMIT} \
    --cpus ${CPU_LIMIT} \
    [image]:[version]

ExecStop=/usr/bin/podman stop -t 30 [addon-name]
Restart=on-failure
RestartSec=10

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/mnt/data/[addon-name]

[Install]
WantedBy=multi-user.target
```

### Security hardening
- `NoNewPrivileges=true` - Forhindrer privilege escalation
- `ProtectSystem=strict` - Beskytter systemfiler
- `ProtectHome=true` - Beskytter home directories
- `PrivateTmp=true` - Isolerer /tmp
- `ReadWritePaths=` - Specificer kun nødvendige write paths

## Fejlhåndtering

### Exit codes
- `0` - Success
- `1` - Generel fejl
- `2` - Konfigurationsfejl
- `3` - Permission fejl
- `4` - Network fejl
- `5` - Container fejl

### Logging
Alle scripts skal logge til både stdout og `/var/log/humethix/addon-[navn].log`:

```bash
log() { 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "/var/log/humethix/addon-${ADDON_NAME}.log"
}
error() { 
    log "FEJL: $*" >&2
    exit 1
}
```

## Eksempel: Minimalt Addon

Her er et komplet minimalt eksempel på et addon:

### config.env.example
```bash
# Simple Web Service Configuration
PORT=8080
EXPOSE_EXTERNAL=false
SUBDOMAIN="simple"
IMAGE_VERSION="latest"
MEMORY_LIMIT="256m"
CPU_LIMIT="0.5"
```

### install.sh (minimal version)
```bash
#!/bin/bash
set -euo pipefail

ADDON_NAME="simple"
SERVICE_USER="$ADDON_NAME"
DATA_DIR="/mnt/data/${ADDON_NAME}"
SECRETS_DIR="/etc/humethix/secrets/${ADDON_NAME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

# Opret user
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd --system --shell /usr/bin/nologin "$SERVICE_USER"
fi

# Opret mapper
mkdir -p "$DATA_DIR" "$SECRETS_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
chmod 700 "$SECRETS_DIR"

# Installer service
cp "${SCRIPT_DIR}/${ADDON_NAME}.service" "/etc/systemd/system/"
systemctl daemon-reload
systemctl enable "$ADDON_NAME"
systemctl start "$ADDON_NAME"

# Registrer backup
echo "$DATA_DIR" >> /etc/humethix/backup-paths.conf
```

## Testing

### Test scenarie
Et addon skal bestå følgende test:

1. **Idempotency test**
   ```bash
   # Kør 3 gange - samme resultat hver gang
   sudo ./install.sh
   sudo ./install.sh
   sudo ./install.sh
   ```

2. **Service test**
   ```bash
   systemctl status [addon-name]
   curl -f http://127.0.0.1:${PORT}/health  # hvis health endpoint
   ```

3. **Uninstall test**
   ```bash
   sudo ./uninstall.sh
   # Service er stoppet, data bevaret
   
   sudo ./uninstall.sh --purge
   # Alt er fjernet
   ```

### Validering
Brug addon-manager.sh til validering:
```bash
./addon-manager.sh validate [addon-name]
```

## Versionering

- Brug semantic versioning (MAJOR.MINOR.PATCH)
- MAJOR: Breaking changes
- MINOR: New features
- PATCH: Bug fixes

Opdater altid `ADDON_VERSION` variablen i install.sh ved nye versioner.

## Bidrag

Nye addons skal følge denne specifikation og testes grundigt før de tilføjes til `available/` mappen.

Alle addons skal have:
- Klar dokumentation i README.md
- Fungerende install/uninstall scripts
- Sikkerhedsvurdering
- Test scenarier
