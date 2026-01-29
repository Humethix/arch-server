#!/bin/bash
# Cloudflare Tunnel Setup Script for Arch Linux v5.1
# Run this AFTER Ansible deployment completes

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

clear
cat << 'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║           CLOUDFLARE TUNNEL SETUP                        ║
║           Arch Linux v5.1                                ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF

echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Step 1: Install cloudflared
log "Step 1: Installing cloudflared..."

if command -v cloudflared &>/dev/null; then
    log "✓ Cloudflared already installed"
    cloudflared --version
else
    cd /tmp
    
    # Download latest cloudflared
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) CF_ARCH="amd64" ;;
        aarch64) CF_ARCH="arm64" ;;
        armv7l) CF_ARCH="arm" ;;
        *) error "Unsupported architecture: $ARCH" ;;
    esac
    
    log "Downloading cloudflared for $CF_ARCH..."
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -O cloudflared
    
    chmod +x cloudflared
    mv cloudflared /usr/local/bin/
    
    log "✓ Cloudflared installed"
    cloudflared --version
fi

# Step 2: Login to Cloudflare
log ""
log "Step 2: Login to Cloudflare"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "This will open a browser window (or display a URL)"
info "Login with your Cloudflare account and authorize the tunnel"
echo ""
read -r -p "Press Enter to continue..."

cloudflared tunnel login

# Check if login succeeded
if [ ! -f ~/.cloudflared/cert.pem ]; then
    error "Login failed - cert.pem not found"
fi

log "✓ Logged in successfully"

# Step 3: Create tunnel
log ""
log "Step 3: Creating tunnel..."

TUNNEL_NAME="archserver-$(hostname)"

# Check if tunnel exists
if cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
    warn "Tunnel '$TUNNEL_NAME' already exists"
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
else
    cloudflared tunnel create "$TUNNEL_NAME"
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
fi

if [ -z "$TUNNEL_ID" ]; then
    error "Failed to get tunnel ID"
fi

log "✓ Tunnel ID: $TUNNEL_ID"

# Step 4: Get domain from user
log ""
log "Step 4: Domain configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -r -p "Enter your domain (e.g., server.example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    warn "No domain specified - using tunnel URL only"
    DOMAIN=""
fi

# Step 5: Create config
log ""
log "Step 5: Creating configuration..."

mkdir -p /etc/cloudflared

if [ -n "$DOMAIN" ]; then
    cat > /etc/cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:80
  - hostname: "*.${DOMAIN#*.}"
    service: http://localhost:80
  - service: http_status:404
EOF
else
    cat > /etc/cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json

ingress:
  - service: http://localhost:80
EOF
fi

# Copy credentials
cp /root/.cloudflared/"${TUNNEL_ID}".json /etc/cloudflared/ 2>/dev/null || true

log "✓ Configuration created"

# Step 6: Route DNS
if [ -n "$DOMAIN" ]; then
    log ""
    log "Step 6: Routing DNS..."
    cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" || warn "DNS routing failed - configure manually in Cloudflare dashboard"
    log "✓ DNS routed"
fi

# Step 7: Create systemd service
log ""
log "Step 7: Creating systemd service..."

cat > /etc/systemd/system/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudflared
systemctl start cloudflared

log "✓ Service created and started"

# Step 8: Verify
log ""
log "Step 8: Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 3

if systemctl is-active cloudflared &>/dev/null; then
    log "✓ Cloudflared service is running"
else
    warn "Cloudflared service not running - check logs"
    journalctl -u cloudflared -n 20 --no-pager
fi

# Summary
cat << EOF

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         ✓ CLOUDFLARE TUNNEL SETUP COMPLETE!              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Tunnel Name: $TUNNEL_NAME
Tunnel ID: $TUNNEL_ID
EOF

if [ -n "$DOMAIN" ]; then
    echo "
Your server is now accessible at:
  🌐 https://$DOMAIN

DNS propagation may take 2-5 minutes.
"
else
    echo "
Your tunnel URL (from Cloudflare dashboard):
  cloudflared tunnel info $TUNNEL_NAME
"
fi

echo "
Useful commands:
  • Status:  systemctl status cloudflared
  • Logs:    journalctl -u cloudflared -f
  • Info:    cloudflared tunnel info $TUNNEL_NAME
  • List:    cloudflared tunnel list
  • Metrics: cloudflared tunnel --metrics localhost:3000
"
