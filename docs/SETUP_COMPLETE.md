# Lara-Berry Complete Setup Guide

## ✓ Current Status

All containers have been freshly started and are running:

- ✅ **Technitium DNS Server** (http://192.168.88.165:5381)
- ✅ **Nginx Proxy Manager** (http://192.168.88.165:8081)
- ✅ **Vaultwarden** (http://192.168.88.165:8082)
- ✅ **Uptime Kuma** (http://192.168.88.165:3001)
- ✅ **WireGuard VPN** (192.168.88.165:51820/UDP)

## Step 1: Access Nginx Proxy Manager

1. Open your browser: **http://192.168.88.165:8081**
2. Log in with default credentials:
   - Email: `admin@example.com`
   - Password: `changeme`

## Step 2: Create Proxy Hosts for vaultwarden.lara-berry

Click **Proxy Hosts** → **Add Proxy Host** and configure:

### Proxy Host 1: Vaultwarden

| Setting | Value |
|---------|-------|
| **Domain Names** | `vaultwarden.lara-berry` |
| **Scheme** | `http` |
| **Forward Hostname/IP** | `vaultwarden` |
| **Forward Port** | `80` |
| **Block Common Exploits** | ✓ Enable |
| **WebSocket Support** | ✓ Enable |

Save without SSL for now.

### Proxy Host 2: Uptime Monitoring

| Setting | Value |
|---------|-------|
| **Domain Names** | `uptime.lara-berry` |
| **Scheme** | `http` |
| **Forward Hostname/IP** | `uptime-kuma` |
| **Forward Port** | `3001` |
| **Block Common Exploits** | ✓ Enable |
| **WebSocket Support** | ✓ Enable |

### Proxy Host 3: Technitium DNS (Optional)

| Setting | Value |
|---------|-------|
| **Domain Names** | `lara-berry` |
| **Scheme** | `http` |
| **Forward Hostname/IP** | `technitium-dns` |
| **Forward Port** | `5380` |
| **Block Common Exploits** | ✓ Enable |

## Step 3: Request SSL Certificates

For each proxy host above:

1. Find the proxy host in the list
2. Click the pencil (edit) icon
3. Scroll to **SSL** tab
4. Click **Request a new SSL Certificate**
5. Select **Let's Encrypt** as provider
6. Check these options:
   - ✓ **Force SSL** (for HTTPS redirect)
   - ✓ **HTTP/2 Support**
   - ✓ **HSTS Enabled**
7. **Save**

Wait 1-2 minutes for certificate to be issued.

## Step 4: Configure DNS Resolution

### Option A: Windows Hosts File (Quick, Local Only)

Edit: `C:\Windows\System32\drivers\etc\hosts`

Add this line at the end:

```
192.168.88.165  vaultwarden.lara-berry uptime.lara-berry lara-berry
```

Then you can access:
- https://vaultwarden.lara-berry:8443
- https://uptime.lara-berry:8443

### Option B: Configure Technitium DNS (Better, Network-Wide)

1. Open: http://192.168.88.165:5381
2. Log in (default: admin/admin)
3. Click **Zones** in left menu
4. Click **Create Zone**
   - Zone Name: `lara-berry`
   - Zone Type: Primary
5. Once created, add these A records:
   - Name: `@` → Address: `192.168.88.165`
   - Name: `vaultwarden` → Address: `192.168.88.165`
   - Name: `uptime` → Address: `192.168.88.165`
   - Name: `*` (wildcard) → Address: `192.168.88.165`
6. Save each record

Then configure your client to use DNS: `192.168.88.165:5353`

**Note**: DNS is on port 5353 (not standard 53) due to rootless Podman limitations.

## Step 5: Test Access

Once SSL certificates are ready and DNS is configured:

**Via HTTPS (with SSL):**
```
https://vaultwarden.lara-berry
https://uptime.lara-berry
```

**Via HTTPS (with port specified):**
```
https://vaultwarden.lara-berry:8443
https://uptime.lara-berry:8443
```

**Via HTTP (without SSL, for testing):**
```
http://vaultwarden.lara-berry:8080
http://uptime.lara-berry:8080
```

**Direct access (bypass Nginx):**
```
http://192.168.88.165:8082      # Vaultwarden
http://192.168.88.165:3001      # Uptime Kuma
http://192.168.88.165:5381      # Technitium DNS
```

## Troubleshooting

### Proxy showing error after creation

Wait a few seconds and refresh. The container names resolve after a moment.

### SSL certificate not issuing

1. Make sure domain resolves correctly
2. Check Let's Encrypt can access http://vaultwarden.lara-berry:8080
3. View proxy host details for error messages
4. Try requesting again

### Can't access vaultwarden.lara-berry

Make sure you:
1. Added proxy host in Nginx ✓
2. Configured DNS (either hosts file or Technitium) ✓
3. Are using correct protocol (http:// or https://) ✓

### DNS not resolving

Verify:
1. Zones exist in Technitium: http://192.168.88.165:5381
2. A records are created for your domain
3. Client DNS points to 192.168.88.165:5353 (not 53)
4. Check with: `nslookup -port=5353 vaultwarden.lara-berry 192.168.88.165`

## Container Management

### Check status
```bash
ssh lara@192.168.88.165 "cd lara-berry && podman-compose ps"
```

### View logs
```bash
ssh lara@192.168.88.165 "cd lara-berry && podman-compose logs -f nginx-proxy-manager"
```

### Restart a service
```bash
ssh lara@192.168.88.165 "cd lara-berry && podman-compose restart vaultwarden"
```

### Stop all services
```bash
ssh lara@192.168.88.165 "cd lara-berry && podman-compose down"
```

### Start all services
```bash
ssh lara@192.168.88.165 "cd lara-berry && podman-compose up -d"
```

## Next Steps

1. ✅ Create Vaultwarden account at https://vaultwarden.lara-berry
2. ✅ Import/save passwords to Vaultwarden
3. ✅ Configure Uptime Kuma monitoring at https://uptime.lara-berry
4. ✅ Set up WireGuard for VPN access (optional)
5. ✅ Customize Technitium DNS settings if needed

## File Locations

On Raspberry Pi at `/home/lara/lara-berry/`:
- `docker-compose.yml` - Container configuration
- `.env` - Environment variables
- `data/technitium/` - DNS data & zones
- `data/npm/data/` - Nginx Proxy Manager data
- `data/vaultwarden/` - Vaultwarden data & vault
- `data/uptime-kuma/` - Uptime Kuma data
- `data/wireguard/` - WireGuard configuration

