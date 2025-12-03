# Lara-Berry Setup Guide

## Current Status

All containers are running successfully on **192.168.88.165**

✅ Technitium DNS Server
✅ Nginx Proxy Manager  
✅ Vaultwarden
✅ Uptime Kuma
✅ WireGuard VPN

## Manual Setup Instructions

Since the Nginx API may not be immediately available, follow these manual steps:

### Step 1: Access Nginx Proxy Manager Web UI

1. Open browser to: **http://192.168.88.165:8081**
2. Log in with:
   - Email: `admin@example.com`
   - Password: `changeme`

### Step 2: Create Proxy Hosts

Go to **Proxy Hosts** → **Add Proxy Host** and create these entries:

#### Host 1: Vaultwarden
- **Domain Names**: `vaultwarden.lara-berry`
- **Scheme**: `http`
- **Forward Hostname/IP**: `vaultwarden`
- **Forward Port**: `80`
- **Block Common Exploits**: ✓
- **WebSocket Support**: ✓
- **SSL**: (leave blank for now, will request later)
- **Save**

#### Host 2: Uptime Monitoring
- **Domain Names**: `uptime.lara-berry`
- **Scheme**: `http`
- **Forward Hostname/IP**: `uptime-kuma`
- **Forward Port**: `3001`
- **Block Common Exploits**: ✓
- **WebSocket Support**: ✓
- **Save**

#### Host 3: DNS Admin (Optional)
- **Domain Names**: `lara-berry`
- **Scheme**: `http`
- **Forward Hostname/IP**: `technitium-dns`
- **Forward Port**: `5380`
- **Block Common Exploits**: ✓
- **Save**

### Step 3: Request SSL Certificates

For each proxy host:

1. Click the **Edit** button (pencil icon)
2. Go to **SSL** tab
3. Click **Request a new SSL Certificate**
4. Select **Let's Encrypt**
5. Check **Force SSL** to enable HTTPS redirection
6. Check **HTTP/2 Support** and **HSTS Enabled**
7. **Save**

### Step 4: Test HTTPS Access

Once SSL certificates are installed, access your services:

```
https://vaultwarden.lara-berry:8443
https://uptime.lara-berry:8443
https://lara-berry:8443  (DNS admin)
```

Or without the port if your client DNS is configured:

```
https://vaultwarden.lara-berry
https://uptime.lara-berry
```

## Service Access URLs

### Direct Access (HTTP on port 8080)
```
http://vaultwarden.lara-berry:8080
http://uptime.lara-berry:8080
http://lara-berry:8080
```

### Admin Panels
```
Nginx Proxy Manager:    http://192.168.88.165:8081
Technitium DNS Admin:   http://192.168.88.165:5381
Vaultwarden Direct:     http://192.168.88.165:8082
Uptime Kuma Direct:     http://192.168.88.165:3001
```

## Configure DNS Resolution

You have two options:

### Option A: Add to Windows Hosts File (Quick)

Edit: `C:\Windows\System32\drivers\etc\hosts`

Add this line:
```
192.168.88.165  vaultwarden.lara-berry uptime.lara-berry lara-berry
```

### Option B: Configure Technitium DNS (Better)

1. Open: http://192.168.88.165:5381
2. Log in with default credentials (admin/admin)
3. Go to **Zones**
4. Create zone: `lara-berry`
5. Add A records:
   - `@` → `192.168.88.165`
   - `vaultwarden` → `192.168.88.165`
   - `uptime` → `192.168.88.165`
   - `*` (wildcard) → `192.168.88.165`
6. Configure your client's DNS to point to `192.168.88.165:5353`

## Troubleshooting

**DNS not resolving?**
- Check Technitium is running: `ssh lara@192.168.88.165 "podman-compose ps"`
- Verify DNS zones exist at http://192.168.88.165:5381
- Make sure clients are using DNS port 5353 (note: not standard port 53 due to rootless Podman)

**Proxy not working?**
- Check Nginx Proxy Manager logs: `ssh lara@192.168.88.165 "cd lara-berry && podman-compose logs nginx-proxy-manager"`
- Verify proxy hosts are created in the web UI
- Test with: `curl -H "Host: vaultwarden.lara-berry" http://192.168.88.165:8080`

**Vaultwarden not starting?**
- Check DOMAIN variable is set correctly in `.env`
- Verify with: `ssh lara@192.168.88.165 "cat lara-berry/.env | grep DOMAIN"`
- Should show: `DOMAIN=https://vaultwarden.lara-berry`

## Next Steps

After setting up proxy hosts and SSL:

1. Create Vaultwarden account at https://vaultwarden.lara-berry
2. Set up Uptime Kuma monitoring at https://uptime.lara-berry
3. Configure WireGuard for remote VPN access
4. Add additional proxy hosts as needed for other services

## Files

- **Setup script**: `/root/lara-berry/setup.sh`
- **Docker Compose**: `/root/lara-berry/docker-compose.yml`
- **Environment config**: `/root/lara-berry/.env`
- **Technitium data**: `/root/lara-berry/data/technitium/`
- **Nginx data**: `/root/lara-berry/data/npm/data/`
- **Vaultwarden data**: `/root/lara-berry/data/vaultwarden/`

