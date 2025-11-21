# MikroTik RB760iGS Setup for Lara-Berry Remote Access

This guide provides specific instructions for configuring your MikroTik RB760iGS router to enable remote access to your Lara-Berry services on the Raspberry Pi.

## Prerequisites
- MikroTik RB760iGS with RouterOS installed.
- Access to the router's web interface (WebFig) or Winbox.
- Your Raspberry Pi's local IP (e.g., 192.168.88.165).
- External IP or DDNS domain.

## Accessing the Router
1. Connect to your MikroTik via Ethernet or Wi-Fi.
2. Open a web browser and go to `http://192.168.88.1` (default IP) or your router's IP.
3. Log in with admin credentials (default: admin / no password, change immediately).

Alternatively, use Winbox for a more user-friendly interface.

## Port Forwarding Setup
To allow external access to your services, set up destination NAT (DNAT) rules.

### Using WebFig (Web Interface)
1. Navigate to **IP > Firewall > NAT**.
2. Click **+** to add a new NAT rule.
3. Configure each port as follows:

#### For Vaultwarden (HTTPS on port 443, forwarded to Pi:443)
- **Chain**: `dstnat`
- **Protocol**: `6 (tcp)`
- **Dst. Address**: (leave blank for all)
- **Dst. Port**: `443`
- **In. Interface**: `ether1` (your WAN interface, check Interfaces menu)
- **Action**: `dst-nat`
- **To Addresses**: `192.168.88.165` (your Pi's IP)
- **To Ports**: `443`
- Click **OK**.

#### For Webmin (port 10000)
- **Chain**: `dstnat`
- **Protocol**: `6 (tcp)`
- **Dst. Port**: `10000`
- **In. Interface**: `ether1`
- **Action**: `dst-nat`
- **To Addresses**: `192.168.88.165`
- **To Ports**: `10000`

#### For Nginx Proxy Manager (ports 80, 81)
- Repeat for port 80:
  - Dst. Port: `80`, To Ports: `80`
- For port 81:
  - Dst. Port: `81`, To Ports: `81`

#### For Technitium DNS (port 5380)
- Dst. Port: `5380`, To Ports: `5380`

#### For Uptime Kuma (port 3001)
- Dst. Port: `3001`, To Ports: `3001`

#### For WireGuard (UDP port 51820)
- **Protocol**: `17 (udp)`
- Dst. Port: `51820`, To Ports: `51820`

If you prefer the CLI, connect via SSH or the router's terminal and run these commands (replace `ether1` with your WAN interface; run `/interface print` to find the correct name, e.g., ether1, sfp1, or wlan1):

First, set DNS:
```
/ip dns set servers=192.168.88.165
```

Then, add NAT rules using hostname:
```
/ip firewall nat
add action=dst-nat chain=dstnat dst-port=443 in-interface=ether1 protocol=tcp to-addresses=lara-berry to-ports=443
add action=dst-nat chain=dstnat dst-port=10000 in-interface=ether1 protocol=tcp to-addresses=lara-berry to-ports=10000
add action=dst-nat chain=dstnat dst-port=80 in-interface=ether1 protocol=tcp to-addresses=lara-berry to-ports=80
add action=dst-nat chain=dstnat dst-port=81 in-interface=ether1 protocol=tcp to-addresses=lara-berry to-ports=81
add action=dst-nat chain=dstnat dst-port=5380 in-interface=ether1 protocol=tcp to-addresses=lara-berry to-ports=5380
add action=dst-nat chain=dstnat dst-port=3001 in-interface=ether1 protocol=tcp to-addresses=lara-berry to-ports=3001
add action=dst-nat chain=dstnat dst-port=51820 in-interface=ether1 protocol=udp to-addresses=lara-berry to-ports=51820
```

To view current NAT rules: `/ip firewall nat print`

To remove a rule: `/ip firewall nat remove [number]`

## Firewall Considerations
Ensure your firewall allows the forwarded traffic:
1. Go to **IP > Firewall > Filter Rules**.
2. Add rules to allow input on the WAN interface for the forwarded ports.
   - Chain: `input`
   - Protocol: TCP/UDP
   - Dst. Port: [port]
   - In. Interface: `ether1`
   - Action: `accept`

## DNS Setup for Hostname Resolution
To use hostnames in NAT rules, configure MikroTik to use your Pi as DNS server:
1. Go to **IP > DNS**.
2. Set **Servers**: `192.168.88.165` (your Pi's IP).
3. Enable **Allow Remote Requests** if needed.
4. Click **OK**.

This allows MikroTik to resolve `lara-berry` to your Pi's IP.

## Testing
- From an external device (not on your local network), try accessing `https://your-ddns-domain` (for Vaultwarden).
- Check logs in **Log** menu for any NAT or firewall issues.

## Security Notes
- Change default admin password.
- Disable unnecessary services.
- Regularly update RouterOS.
- Monitor access logs.

For more details, refer to the MikroTik Wiki: https://wiki.mikrotik.com/wiki/Main_Page