# Lara-Berry Service Access Guide

## Current Service Status

All services are running successfully on Raspberry Pi at `192.168.88.165`. Use the ports below to access them:

### Services & Access Points

| Service | Web Console | Notes |
|---------|-------------|-------|
| **Technitium DNS** | http://192.168.88.165:5381 | DNS server web UI (login required) |
| **Nginx Proxy Manager** | http://192.168.88.165:8081 | Reverse proxy & certificate manager |
| **Vaultwarden** | http://192.168.88.165:8082 | Bitwarden-compatible password manager |
| **Uptime Kuma** | http://192.168.88.165:3001 | Service monitoring & uptime tracking |
| **WireGuard VPN** | 192.168.88.165:51820 | VPN server (UDP) |

### Port Mapping Reference

```
Container Port  →  Host Port  →  Access URL
5380 (Technitium web)  →  5381  →  http://192.168.88.165:5381
80 (Nginx HTTP)        →  8080  →  http://192.168.88.165:8080
81 (Nginx Admin)       →  8081  →  http://192.168.88.165:8081
443 (Nginx HTTPS)      →  8443  →  https://192.168.88.165:8443
80 (Vaultwarden)       →  8082  →  http://192.168.88.165:8082
3001 (Uptime Kuma)     →  3001  →  http://192.168.88.165:3001
51820 (WireGuard)      →  51820 →  UDP, VPN connections
```

### DNS Configuration

**Important**: Due to rootless Podman limitations, DNS port 53 is NOT accessible externally.
- **Internal DNS**: Technitium is running on container port 53 but cannot bind to host port 53
- **Alternatives**:
  1. Configure clients to manually point to Technitium web console (port 5381) for zone management
  2. Use `/etc/hosts` entries on client machines: `192.168.88.165 lara-berry vaultwarden.lara-berry`
  3. Restart Podman with rootful mode (requires host configuration changes)

### Next Steps

1. **Configure Nginx Proxy Manager**:
   - Access http://192.168.88.165:8081
   - Default login: `admin@example.com` / `changeme`
   - Add proxy hosts for each service (Vaultwarden, Uptime Kuma, etc.)
   - Request SSL certificates via Let's Encrypt

2. **Configure HTTPS**:
   - In Nginx Proxy Manager, create proxy hosts with SSL
   - Example: `vaultwarden.lara-berry` → `http://192.168.88.165:8082/`

3. **Add DNS Records** (Optional):
   - Log in to Technitium at http://192.168.88.165:5381
   - Create A records pointing to 192.168.88.165 for your domain zones

### Service Health Check

Run this command to verify all services are running:

```bash
ssh lara@192.168.88.165 "cd lara-berry && podman-compose ps"
```

All containers should show status: `Up X minutes`

### Configuration Files

- **Environment variables**: `.env`
- **Container orchestration**: `docker-compose.yml`
- **Technitium DNS data**: `data/technitium/`
- **Vaultwarden data**: `data/vaultwarden/`
- **Nginx config**: `data/npm/data/`
