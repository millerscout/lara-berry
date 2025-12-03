#!/bin/bash
# Lara-Berry Setup Script
# Configures Nginx Proxy Manager after containers start
# Usage: bash setup.sh [npm_host] [npm_port] [domain]

NPM_HOST="${1:-192.168.88.165}"
NPM_PORT="${2:-8081}"
DOMAIN="${3:-lara-berry}"

echo "=================================================="
echo "Lara-Berry Setup Script"
echo "=================================================="
echo ""
echo "Configuration:"
echo "  NPM Host: $NPM_HOST"
echo "  NPM Port: $NPM_PORT"  
echo "  Domain: $DOMAIN"
echo ""

# Wait for NPM to be ready with exponential backoff
echo "Waiting for Nginx Proxy Manager to initialize..."
WAIT_TIME=0
MAX_WAIT=300  # 5 minutes

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "http://$NPM_HOST:$NPM_PORT/api/tokens" \
      -H "Content-Type: application/json" \
      -d '{"identity":"admin@example.com","secret":"changeme"}' 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "400" ]; then
        # 200 = success, 400 = auth error but API is ready
        echo "✓ Nginx Proxy Manager is ready (HTTP $HTTP_CODE)"
        break
    fi
    
    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
    echo "  Waiting... (${WAIT_TIME}s/$MAX_WAIT) - HTTP $HTTP_CODE"
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo ""
    echo "✗ Nginx Proxy Manager did not respond in time"
    echo "Try again: bash lara-berry/setup.sh"
    exit 1
fi

echo ""
echo "=================================================="
echo "Getting authentication token..."
echo "=================================================="

# Get auth token
TOKEN_JSON=$(curl -s -X POST "http://$NPM_HOST:$NPM_PORT/api/tokens" \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","secret":"changeme"}')

TOKEN=$(echo "$TOKEN_JSON" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "✗ Could not extract token"
    echo "Response: $TOKEN_JSON"
    exit 1
fi

echo "✓ Token obtained"
echo ""

# Function to create proxy host
create_proxy() {
    local domain_name=$1
    local forward_host=$2
    local forward_port=$3
    
    echo "Creating proxy: $domain_name → $forward_host:$forward_port"
    
    curl -s -X POST "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"domain_names\": [\"$domain_name\"],
        \"forward_host\": \"$forward_host\",
        \"forward_port\": $forward_port,
        \"forward_scheme\": \"http\",
        \"block_exploits\": true,
        \"websocket_support\": true,
        \"caching_enabled\": false,
        \"access_list_id\": 0,
        \"certificate_id\": 0,
        \"ssl_forced\": false,
        \"http2_support\": true,
        \"hsts_enabled\": false
      }" > /dev/null 2>&1
    
    echo "  ✓ Created"
}

echo "=================================================="
echo "Creating proxy hosts..."
echo "=================================================="
echo ""

create_proxy "vaultwarden.$DOMAIN" "vaultwarden" 80
create_proxy "uptime.$DOMAIN" "uptime-kuma" 3001
create_proxy "$DOMAIN" "technitium-dns" 5380

echo ""
echo "=================================================="
echo "✓ Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Open browser: http://$NPM_HOST:$NPM_PORT"
echo "  2. Log in: admin@example.com / changeme"
echo "  3. Click each proxy host and request SSL cert"
echo "  4. Enable 'Force SSL' for HTTPS"
echo "  5. Access via: https://vaultwarden.$DOMAIN:8443"
echo ""
echo "Shortcuts:"
echo "  HTTP:  http://vaultwarden.$DOMAIN:8080"
echo "  HTTPS: https://vaultwarden.$DOMAIN:8443"
echo ""
