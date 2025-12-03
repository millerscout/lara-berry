#!/bin/bash
# Post-compose setup script for Lara-Berry
# Run this AFTER: podman-compose up -d
# Usage: ./setup.sh [npm_host] [npm_port] [domain]
#   Default: ./setup.sh 192.168.88.165 8081 lara-berry

set -e

NPM_HOST="${1:-192.168.88.165}"
NPM_PORT="${2:-8081}"
DOMAIN="${3:-lara-berry}"

echo "================================================"
echo "Lara-Berry Post-Compose Setup"
echo "================================================"
echo ""
echo "Configuration:"
echo "  NPM Host: $NPM_HOST"
echo "  NPM Port: $NPM_PORT"
echo "  Domain: $DOMAIN"
echo ""

# Wait for services to be ready
echo "Waiting for services to start..."
RETRY=0
while [ $RETRY -lt 60 ]; do
    if curl -s -f "http://$NPM_HOST:5381" > /dev/null 2>&1; then
        if curl -s "http://$NPM_HOST:$NPM_PORT/api/tokens" -X OPTIONS > /dev/null 2>&1; then
            echo "✓ Services are ready"
            break
        fi
    fi
    if [ $RETRY -lt 59 ]; then
        echo "  Waiting... ($(($RETRY+1))/60)"
        sleep 2
    fi
    RETRY=$((RETRY+1))
done

sleep 5  # Extra wait for API to be fully ready
echo ""

echo "Step 1: Getting Nginx Proxy Manager auth token..."
echo "================================================"

# Retry auth multiple times
AUTH_TOKEN=""
for attempt in {1..5}; do
    AUTH_TOKEN=$(curl -s -X POST "http://$NPM_HOST:$NPM_PORT/api/tokens" \
      -H "Content-Type: application/json" \
      -d '{
        "identity": "admin@example.com",
        "secret": "changeme"
      }' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    if [ -n "$AUTH_TOKEN" ]; then
        echo "✓ Auth token obtained (attempt $attempt)"
        break
    fi
    if [ $attempt -lt 5 ]; then
        echo "  Retrying auth... ($attempt/5)"
        sleep 3
    fi
done

if [ -z "$AUTH_TOKEN" ]; then
    echo "✗ Failed to get auth token after 5 attempts"
    echo "NPM may not be fully initialized. Please wait and run again:"
    echo "  bash ~/lara-berry/setup.sh $NPM_HOST $NPM_PORT $DOMAIN"
    exit 1
fi

echo "Step 2: Creating proxy hosts..."
echo "================================================"

# Create proxy host for Vaultwarden
echo "Creating proxy host: vaultwarden.$DOMAIN..."
curl -s -X POST "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"domain_names\": [\"vaultwarden.$DOMAIN\"],
    \"forward_host\": \"vaultwarden\",
    \"forward_port\": 80,
    \"forward_scheme\": \"http\",
    \"block_exploits\": true,
    \"websocket_support\": true,
    \"caching_enabled\": false,
    \"access_list_id\": 0,
    \"certificate_id\": 0,
    \"ssl_forced\": false,
    \"http2_support\": true,
    \"hsts_enabled\": false,
    \"hsts_subdomains\": false
  }" > /dev/null 2>&1 && echo "✓ vaultwarden.$DOMAIN created" || echo "⚠ Failed to create vaultwarden"

# Create proxy host for Uptime Kuma
echo "Creating proxy host: uptime.$DOMAIN..."
curl -s -X POST "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"domain_names\": [\"uptime.$DOMAIN\"],
    \"forward_host\": \"uptime-kuma\",
    \"forward_port\": 3001,
    \"forward_scheme\": \"http\",
    \"block_exploits\": true,
    \"websocket_support\": true,
    \"caching_enabled\": false,
    \"access_list_id\": 0,
    \"certificate_id\": 0,
    \"ssl_forced\": false,
    \"http2_support\": true,
    \"hsts_enabled\": false,
    \"hsts_subdomains\": false
  }" > /dev/null 2>&1 && echo "✓ uptime.$DOMAIN created" || echo "⚠ Failed to create uptime"

# Create proxy host for Technitium DNS
echo "Creating proxy host: $DOMAIN..."
curl -s -X POST "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"domain_names\": [\"$DOMAIN\"],
    \"forward_host\": \"technitium-dns\",
    \"forward_port\": 5380,
    \"forward_scheme\": \"http\",
    \"block_exploits\": true,
    \"websocket_support\": false,
    \"caching_enabled\": false,
    \"access_list_id\": 0,
    \"certificate_id\": 0,
    \"ssl_forced\": false,
    \"http2_support\": true,
    \"hsts_enabled\": false,
    \"hsts_subdomains\": false
  }" > /dev/null 2>&1 && echo "✓ $DOMAIN created" || echo "⚠ Failed to create $DOMAIN"

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "Access your services:"
echo ""
echo "  Web Access (HTTP via Nginx port 8080):"
echo "    http://vaultwarden.$DOMAIN:8080"
echo "    http://uptime.$DOMAIN:8080"
echo "    http://$DOMAIN:8080"
echo ""
echo "  Admin Panels:"
echo "    Nginx Proxy Manager: http://$NPM_HOST:$NPM_PORT"
echo "      Email: admin@example.com"
echo "      Password: changeme"
echo ""
echo "    Technitium DNS: http://$NPM_HOST:5381"
echo ""
echo "Next Steps:"
echo "  1. Log in to Nginx Proxy Manager"
echo "  2. Edit each proxy host to request SSL certificates"
echo "  3. Enable Force SSL for each host"
echo "  4. Test HTTPS access"
echo ""