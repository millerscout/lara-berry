# Lara-Berry: Podman Environment Setup for Raspberry Pi 4

This repository provides scripts and instructions to set up a Podman-based container environment on a Raspberry Pi 4 running Raspberry Pi OS (64-bit). It also includes Webmin for web-based system administration.

## Prerequisites

- Raspberry Pi 4 with Raspberry Pi OS (64-bit) installed.
- Internet connection for downloading packages.
- Basic familiarity with terminal commands.

## Quick Setup

1. Clone this repository to your Raspberry Pi:
   ```
   git clone https://github.com/millerscout/lara-berry.git
   cd lara-berry
   ```

2. Run the automated setup script (requires sudo):
   ```
   sudo bash setup.sh
   ```

   This script will:
   - Update your system.
   - Install Podman.
   - Configure rootless Podman for your user.
   - Install and configure Webmin.

3. Copy and configure environment variables:
   ```
   cp .env.example .env
   # Edit .env with your domain and other settings
   ```

4. Reboot your Pi (recommended after setup):
   ```
   sudo reboot
   ```

## Post-Setup Configuration

- **Webmin Access**: Open a web browser and go to `https://your-pi-ip:10000`. Log in with your system root credentials (default: root / your root password). Change the password immediately for security.
- **Podman**: You can now run containers as your user (rootless). For example:
  ```
  podman run -d --name hello-world hello-world
  ```
- **Firewall**: Ensure ports 10000 (Webmin) and any container ports are open if needed.

## Running Additional Services

After setup, you can run the included services (Technitium DNS, Nginx Proxy Manager, WireGuard VPN, and Uptime Kuma) using Podman Compose:

1. Ensure you're in the repository directory.
2. Run: `podman-compose up -d`

After setup, the services will start automatically on boot. You can also manually start/stop them with `podman-compose up -d` or `podman-compose down`.
- **Technitium DNS**: http://localhost:5380 (DNS server on port 5353)
- **Nginx Proxy Manager**: http://localhost:81 (admin on port 81, proxy on 80/443)
- **WireGuard**: Config files in `./data/wireguard`, connect using the generated peer configs
- **Uptime Kuma**: http://localhost:3001
- **Vaultwarden**: http://your-pi-ip:8080 (or http://lara-berry:8080 if DNS is set up)

To stop: `podman-compose down`

Note: Adjust ports or configs in `docker-compose.yml` as needed. Ensure no port conflicts.

## Troubleshooting

- **Podman Issues**:
  - If containers fail to start, load required kernel modules: `sudo modprobe overlay && sudo modprobe br_netfilter`
  - For rootless mode, log out and back in after setup.
- **Webmin Issues**:
  - If Webmin doesn't start, check `/var/webmin/miniserv.error` for logs.
  - Ensure port 10000 is not blocked by your firewall.
- **General**:
  - Run `sudo apt update` if package installation fails.
  - Check system logs with `journalctl -u webmin` or `journalctl -u podman`.

## Remote Access Setup

To access your Raspberry Pi and services from outside your local network, you'll need DNS resolution and port forwarding. Here's a basic guide:

### 1. Dynamic DNS (DDNS)
Since your home IP may change, use a DDNS service:
- Sign up for a free service like No-IP, DuckDNS, or Dynu.
- The setup script installs the No-IP Dynamic Update Client (DUC). After setup, run `sudo noip2 -C` and follow the prompts to configure with your No-IP account.
- This gives you a domain like `yourname.ddns.net` pointing to your current IP.

### 2. Port Forwarding
In your router settings, forward the necessary ports to your Pi's local IP (e.g., 192.168.1.100):
- Webmin: 10000
- Nginx Proxy Manager: 80, 81, 443
- Technitium DNS: 5380 (and 5353 if exposing DNS externally, not recommended for security)
- WireGuard: 51820/UDP
- Uptime Kuma: 3001
- Vaultwarden: 8080

**Security Warning**: Only forward ports you need, and use HTTPS where possible. Consider a VPN (WireGuard) for secure access.

### 3. DNS Configuration
- For local DNS: Set your router or devices to use the Pi's IP as primary DNS. Then configure Technitium DNS (via http://your-pi-ip:5380) to add local zones/records (e.g., pi.local -> your Pi IP).
- For external DNS: If you own a domain, delegate it to Technitium (advanced). Otherwise, use your DDNS domain and configure NPM to proxy subdomains (e.g., webmin.yourname.ddns.net -> Pi:10000).

### 4. Using Nginx Proxy Manager
NPM can handle SSL certificates and proxy requests. Access it at http://your-pi-ip:81, add your DDNS domain, and create proxies for each service.

Example: Proxy `webmin.yourdomain.com` to `http://pi-ip:10000`. Enable SSL with Let's Encrypt for automatic certificates.

For each service:
- **Webmin**: Proxy to `http://pi-ip:10000`
- **Technitium DNS**: Proxy to `http://localhost:5380`
- **Uptime Kuma**: Proxy to `http://localhost:3001`
- **Vaultwarden**: Proxy to `http://localhost:8000`
- **WireGuard**: Not typically proxied; access configs directly.

This setup allows secure remote access via domain names with HTTPS.

## Setting up Self-Signed SSL for Vaultwarden

1. **Configure DNS**: After Technitium is running, run `./setup-dns.sh` to automatically create the zone and records for `lara-berry`. Alternatively, access http://your-pi-ip:5380 and manually create a primary zone for `lara-berry` with an A record pointing to your Pi's IP.

2. **Set up environment**:
   ```
   cp .env.example .env
   # Edit .env: DOMAIN=https://lara-berry
   podman-compose down && podman-compose up -d
   ```

3. **Configure Nginx Proxy Manager**:
   - Access at `http://your-pi-ip:81`
   - **SSL Certificates** > **Add SSL Certificate** > **Self-signed** for domain `lara-berry`
   - **Proxy Hosts** > **Add Proxy Host**:
     - Domain: `lara-berry`
     - Forward to: `http://your-pi-ip:8080`
     - Enable SSL, select the self-signed certificate

4. **Access Vaultwarden**: Go to `https://lara-berry`, accept the certificate warning. The Web Crypto API should now work over HTTPS.