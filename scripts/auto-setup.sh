#!/bin/bash
# Automatic setup script for Lara-Berry Home Server
# Run this AFTER: podman-compose up -d
# Usage: ./auto-setup.sh [npm_host] [npm_port] [domain]
#        ./auto-setup.sh 192.168.88.165 8081 lara-berry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NPM_HOST="${1:-192.168.88.165}"
NPM_PORT="${2:-8081}"
DOMAIN="${3:-lara-berry}"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Lara-Berry Automatic Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Configuration:"
echo "  NPM Host: $NPM_HOST"
echo "  NPM Port: $NPM_PORT"
echo "  Domain: $DOMAIN"
echo ""

# ============================================================================
# Function: Retry with backoff
# ============================================================================
retry_with_backoff() {
    local max_attempts=30
    local timeout=1
    local attempt=1
    local exitstatus=0
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$@"; then
            return 0
        else
            exitstatus=$?
        fi
        echo -e "${YELLOW}  Attempt $attempt/$max_attempts failed, waiting ${timeout}s...${NC}"
        sleep $timeout
        timeout=$((timeout < 32 ? timeout * 2 : 32))
        attempt=$((attempt + 1))
    done
    
    return $exitstatus
}

# ============================================================================
# Step 1: Wait for services to be ready
# ============================================================================
echo -e "${BLUE}Step 1: Waiting for services to start...${NC}"
echo ""

echo "  Checking Technitium DNS on port 5381..."
retry_with_backoff "curl -s -f http://$NPM_HOST:5381/api/system/stats > /dev/null 2>&1"
echo -e "${GREEN}  ✓ Technitium DNS ready${NC}"

echo "  Checking Nginx Proxy Manager on port $NPM_PORT..."
retry_with_backoff "curl -s -f http://$NPM_HOST:$NPM_PORT > /dev/null 2>&1"
echo -e "${GREEN}  ✓ Nginx Proxy Manager ready${NC}"

echo "  Checking Vaultwarden on port 8082..."
retry_with_backoff "curl -s -f http://$NPM_HOST:8082 > /dev/null 2>&1"
echo -e "${GREEN}  ✓ Vaultwarden ready${NC}"

echo "  Checking Uptime Kuma on port 3001..."
retry_with_backoff "curl -s -f http://$NPM_HOST:3001 > /dev/null 2>&1"
echo -e "${GREEN}  ✓ Uptime Kuma ready${NC}"

echo ""

# ============================================================================
# Step 2: Get authentication token
# ============================================================================
echo -e "${BLUE}Step 2: Authenticating with Nginx Proxy Manager...${NC}"
echo ""

AUTH_TOKEN=""
retry_with_backoff "AUTH_TOKEN=\$(curl -s -X POST 'http://$NPM_HOST:$NPM_PORT/api/tokens' \
  -H 'Content-Type: application/json' \
  -d '{
    \"identity\": \"admin@example.com\",
    \"secret\": \"changeme\"
  }' | grep -o '\"token\":\"[^\"]*' | cut -d'\"' -f4) && [ -n \"\$AUTH_TOKEN\" ]"

if [ -z "$AUTH_TOKEN" ]; then
    echo -e "${RED}✗ Failed to get authentication token${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify Nginx is fully initialized (wait 30-60 seconds after docker-compose up)"
    echo "  2. Check default credentials haven't changed: admin@example.com / changeme"
    echo "  3. Try again: bash $0 $NPM_HOST $NPM_PORT $DOMAIN"
    exit 1
fi

echo -e "${GREEN}✓ Authentication successful${NC}"
echo ""

# ============================================================================
# Step 3: Get existing proxy hosts
# ============================================================================
echo -e "${BLUE}Step 3: Checking for existing proxy hosts...${NC}"
echo ""

EXISTING_HOSTS=$(curl -s -X GET "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json")

echo "Existing hosts:"
echo "$EXISTING_HOSTS" | grep -o '"domain_names":\[\("[^"]*"\(,"[^"]*"\)*\)\]' | head -5 || echo "  (none found)"
echo ""

# ============================================================================
# Step 4: Create proxy hosts
# ============================================================================
echo -e "${BLUE}Step 4: Creating proxy hosts...${NC}"
echo ""

# Function to create or update proxy host
create_proxy_host() {
    local domain_name=$1
    local forward_host=$2
    local forward_port=$3
    local websocket=$4
    
    echo -n "  Creating proxy for $domain_name (→ $forward_host:$forward_port)... "
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts" \
      -H "Authorization: Bearer $AUTH_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"domain_names\": [\"$domain_name\"],
        \"forward_host\": \"$forward_host\",
        \"forward_port\": $forward_port,
        \"forward_scheme\": \"http\",
        \"block_exploits\": true,
        \"websocket_support\": $websocket,
        \"caching_enabled\": false,
        \"access_list_id\": 0,
        \"certificate_id\": 0,
        \"ssl_forced\": false,
        \"http2_support\": true,
        \"hsts_enabled\": false,
        \"hsts_subdomains\": false
      }")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    elif echo "$BODY" | grep -q "Domain name already exists"; then
        echo -e "${YELLOW}(already exists)${NC}"
        return 0
    else
        echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
        echo "    Response: $BODY"
        return 1
    fi
}

# Create the three proxy hosts
create_proxy_host "vaultwarden.$DOMAIN" "vaultwarden" "80" "true"
create_proxy_host "uptime.$DOMAIN" "uptime-kuma" "3001" "true"
create_proxy_host "$DOMAIN" "technitium-dns" "5380" "false"

echo ""

# ============================================================================
# Step 5: Configure DNS zones in Technitium (optional)
# ============================================================================
echo -e "${BLUE}Step 5: Configuring DNS zones in Technitium...${NC}"
echo ""

echo "  Note: You can optionally configure DNS zones in Technitium"
echo "  for network-wide domain resolution, or use hosts file for local testing."
echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

echo "Your services are now accessible:"
echo ""
echo -e "${BLUE}HTTP Access (without SSL):${NC}"
echo "  http://$NPM_HOST:8080  (Nginx reverse proxy)"
echo "  http://$NPM_HOST:8081  (Nginx admin panel)"
echo "  http://$NPM_HOST:8082  (Vaultwarden direct)"
echo "  http://$NPM_HOST:3001  (Uptime Kuma direct)"
echo "  http://$NPM_HOST:5381  (Technitium DNS)"
echo ""

echo -e "${BLUE}Login Credentials:${NC}"
echo "  Nginx Proxy Manager:"
echo "    Email: admin@example.com"
echo "    Password: changeme"
echo ""

echo -e "${BLUE}Next Steps for HTTPS Setup:${NC}"
echo ""
echo "  1. Add DNS entries or use hosts file:"
echo "     Windows hosts file: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "     Add these lines:"
echo "       $NPM_HOST vaultwarden.$DOMAIN"
echo "       $NPM_HOST uptime.$DOMAIN"
echo "       $NPM_HOST $DOMAIN"
echo ""
echo "  2. Request SSL certificates:"
echo "     - Log in to http://$NPM_HOST:8081"
echo "     - For each proxy host, click SSL tab"
echo "     - Request Let's Encrypt certificate"
echo "     - Wait 30-60 seconds for certificate issuance"
echo ""
echo "  3. Test HTTPS access:"
echo "     https://vaultwarden.$DOMAIN:8443"
echo "     https://uptime.$DOMAIN:8443"
echo "     https://$DOMAIN:8443"
echo ""
echo "  4. (Optional) Configure DNS zones in Technitium:"
echo "     - Open http://$NPM_HOST:5381"
echo "     - Create zone for $DOMAIN"
echo "     - Add A records pointing to $NPM_HOST"
echo ""

echo -e "${YELLOW}Important Notes:${NC}"
echo "  • Proxy hosts have been created automatically"
echo "  • SSL certificates still need to be requested manually via web UI"
echo "  • For full automation, run: ssh lara@$NPM_HOST 'bash ~/lara-berry/auto-setup.sh'"
echo ""
