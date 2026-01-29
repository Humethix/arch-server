# Templates

Configuration templates for manual customization.

## Files

| Template | Description |
|----------|-------------|
| `Caddyfile.template` | Caddy web server configuration |
| `nftables.template` | Firewall rules |

## Usage

1. Copy template to target location
2. Replace `{{VARIABLE}}` placeholders
3. Reload service

### Example

```bash
# Copy and customize Caddyfile
cp templates/Caddyfile.template /opt/caddy/config/Caddyfile
sed -i 's/{{DOMAIN}}/example.com/g' /opt/caddy/config/Caddyfile
systemctl reload caddy
```
