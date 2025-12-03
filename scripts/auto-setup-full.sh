#!/bin/bash
# Full automatic setup with SSL certificate generation
# Run this AFTER: podman-compose up -d
# Usage: ./auto-setup-full.sh [npm_host] [npm_port] [domain] [email]
#        ./auto-setup-full.sh 192.168.88.165 8081 lara-berry admin@example.com

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
LE_EMAIL="${4:-admin@example.com}"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Lara-Berry Full Automatic Setup with SSL${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Configuration:"
echo "  NPM Host: $NPM_HOST"
echo "  NPM Port: $NPM_PORT"
echo "  Domain: $DOMAIN"
echo "  Let's Encrypt Email: $LE_EMAIL"
echo ""

# ============================================================================
# Function: Retry with backoff
# ============================================================================
retry_with_backoff() {
    local max_attempts=30
    local timeout=1
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$@"; then
            return 0
        fi
        if [ $attempt -lt $max_attempts ]; then
            echo -e "${YELLOW}    Attempt $attempt/$max_attempts failed, waiting ${timeout}s...${NC}"
            sleep $timeout
            timeout=$((timeout < 32 ? timeout * 2 : 32))
        fi
        attempt=$((attempt + 1))
    done
    
    return 1
}

# ============================================================================
# Step 1: Wait for services to be ready
# ============================================================================
echo -e "${BLUE}Step 1: Waiting for services to start...${NC}"
echo ""

echo "  Checking Nginx Proxy Manager..."
retry_with_backoff "curl -s -f http://$NPM_HOST:$NPM_PORT > /dev/null 2>&1"
echo -e "${GREEN}  ✓ Nginx ready${NC}"

echo "  Checking other services..."
curl -s -f http://$NPM_HOST:5381 > /dev/null 2>&1 && echo -e "${GREEN}  ✓ Technitium ready${NC}" || echo -e "${YELLOW}  ⚠ Technitium not responding${NC}"
curl -s -f http://$NPM_HOST:8082 > /dev/null 2>&1 && echo -e "${GREEN}  ✓ Vaultwarden ready${NC}" || echo -e "${YELLOW}  ⚠ Vaultwarden not responding${NC}"
curl -s -f http://$NPM_HOST:3001 > /dev/null 2>&1 && echo -e "${GREEN}  ✓ Uptime Kuma ready${NC}" || echo -e "${YELLOW}  ⚠ Uptime Kuma not responding${NC}"

echo ""

# ============================================================================
# Step 2: Get authentication token
# ============================================================================
echo -e "${BLUE}Step 2: Authenticating...${NC}"
echo ""

AUTH_TOKEN=""
if retry_with_backoff "AUTH_TOKEN=\$(curl -s -X POST 'http://$NPM_HOST:$NPM_PORT/api/tokens' \
  -H 'Content-Type: application/json' \
  -d '{
    \"identity\": \"admin@example.com\",
    \"secret\": \"changeme\"
  }' | grep -o '\"token\":\"[^\"]*' | cut -d'\"' -f4) && [ -n \"\$AUTH_TOKEN\" ]"; then
    echo -e "${GREEN}✓ Authentication successful${NC}"
else
    echo -e "${RED}✗ Failed to get authentication token${NC}"
    echo "  Verify Nginx is fully initialized and default credentials haven't changed."
    exit 1
fi

echo ""

# ============================================================================
# Step 3: Create proxy hosts
# ============================================================================
echo -e "${BLUE}Step 3: Creating proxy hosts...${NC}"
echo ""

create_proxy_host() {
    local domain_name=$1
    local forward_host=$2
    local forward_port=$3
    local websocket=$4
    
    echo -n "  $domain_name... "
    
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
        PROXY_ID=$(echo "$BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        echo -e "${GREEN}✓${NC} (ID: $PROXY_ID)"
        echo "$PROXY_ID"
    elif echo "$BODY" | grep -q "Domain name already exists"; then
        # Get existing proxy ID
        EXISTING=$(curl -s -X GET "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts" \
          -H "Authorization: Bearer $AUTH_TOKEN" | grep -o "\"domain_names\":\[\"$domain_name\"\][^}]*\"id\":[0-9]*" | grep -o '"id":[0-9]*' | cut -d':' -f2)
        echo -e "${YELLOW}(exists)${NC} (ID: $EXISTING)"
        echo "$EXISTING"
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

VAULT_ID=$(create_proxy_host "vaultwarden.$DOMAIN" "vaultwarden" "80" "true")
UPTIME_ID=$(create_proxy_host "uptime.$DOMAIN" "uptime-kuma" "3001" "true")
DNS_ID=$(create_proxy_host "$DOMAIN" "technitium-dns" "5380" "false")

echo ""

# ============================================================================
# Step 4: Create/Get Let's Encrypt certificate
# ============================================================================
echo -e "${BLUE}Step 4: Setting up Let's Encrypt certificates...${NC}"
echo ""

# First, create a Let's Encrypt certificate entry
echo "  Creating Let's Encrypt certificate..."

LE_RESPONSE=$(curl -s -X POST "http://$NPM_HOST:$NPM_PORT/api/certificates" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"provider\": \"letsencrypt\",
    \"certificate_name\": \"LetsEncrypt\",
    \"meta\": {
      \"domains\": [\"$DOMAIN\", \"vaultwarden.$DOMAIN\", \"uptime.$DOMAIN\"],
      \"email\": \"$LE_EMAIL\"
    }
  }")

LE_CERT_ID=$(echo "$LE_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$LE_CERT_ID" ]; then
    echo -e "${YELLOW}  ⚠ Could not auto-create certificate${NC}"
    echo "     (This may need to be done manually via web UI)"
    LE_CERT_ID="0"
else
    echo -e "${GREEN}  ✓ Certificate entry created (ID: $LE_CERT_ID)${NC}"
fi

echo ""

# ============================================================================
# Step 5: Update proxy hosts with SSL certificate
# ============================================================================
if [ "$LE_CERT_ID" != "0" ]; then
    echo -e "${BLUE}Step 5: Applying SSL certificates to proxy hosts...${NC}"
    echo ""
    
    update_proxy_ssl() {
        local proxy_id=$1
        local domain_name=$2
        
        echo -n "  Updating $domain_name... "
        
        UPDATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts/$proxy_id" \
          -H "Authorization: Bearer $AUTH_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{
            \"certificate_id\": $LE_CERT_ID,
            \"ssl_forced\": true,
            \"hsts_enabled\": true,
            \"hsts_subdomains\": true
          }")
        
        UPDATE_CODE=$(echo "$UPDATE_RESPONSE" | tail -n 1)
        
        if [ "$UPDATE_CODE" = "200" ]; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}⚠${NC} (Manual SSL config needed)"
        fi
    }
    
    if [ -n "$VAULT_ID" ]; then
        update_proxy_ssl "$VAULT_ID" "vaultwarden.$DOMAIN"
    fi
    if [ -n "$UPTIME_ID" ]; then
        update_proxy_ssl "$UPTIME_ID" "uptime.$DOMAIN"
    fi
    if [ -n "$DNS_ID" ]; then
        update_proxy_ssl "$DNS_ID" "$DOMAIN"
    fi
    
    echo ""
fi

# ============================================================================
# Summary
# ============================================================================
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

echo "Your services are now running:"
echo ""
echo -e "${BLUE}Dashboard Access:${NC}"
echo "  Nginx Proxy Manager Admin: http://$NPM_HOST:8081"
echo "  Technitium DNS Console: http://$NPM_HOST:5381"
echo ""

echo -e "${BLUE}Proxy Hosts Created:${NC}"
echo "  • vaultwarden.$DOMAIN → http://$NPM_HOST:8080/vaultwarden"
echo "  • uptime.$DOMAIN → http://$NPM_HOST:8080/uptime"
echo "  • $DOMAIN → http://$NPM_HOST:8080 (Technitium DNS)"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo ""
if [ "$LE_CERT_ID" = "0" ]; then
    echo "  1. Manual SSL Certificate Setup (via Web UI):"
    echo "     - Log in to http://$NPM_HOST:8081 (admin@example.com/changeme)"
    echo "     - For EACH proxy host:"
    echo "       • Click 'SSL' tab"
    echo "       • Select 'Let's Encrypt' certificate provider"
    echo "       • Request certificate for: $DOMAIN, vaultwarden.$DOMAIN, uptime.$DOMAIN"
    echo "       • Check 'Force SSL' and 'HSTS'"
    echo ""
    echo "  2. Configure DNS:"
else
    echo "  1. Wait for Let's Encrypt certificates to issue (2-5 minutes)"
    echo "     Check certificate status: http://$NPM_HOST:8081/nginx/certificates"
    echo ""
    echo "  2. Test HTTPS (once certificates are issued):"
    echo "     https://vaultwarden.$DOMAIN:8443"
    echo "     https://uptime.$DOMAIN:8443"
    echo "     https://$DOMAIN:8443"
    echo ""
    echo "  3. Configure DNS:"
fi
echo "     Option A - Windows hosts file (local only):"
echo "       Edit: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "       Add:"
echo "         $NPM_HOST vaultwarden.$DOMAIN"
echo "         $NPM_HOST uptime.$DOMAIN"
echo "         $NPM_HOST $DOMAIN"
echo ""
echo "     Option B - Technitium DNS zones (network-wide):"
echo "       1. Open http://$NPM_HOST:5381"
echo "       2. Create zone for: $DOMAIN"
echo "       3. Add A records pointing to: $NPM_HOST"
echo "       4. Set your device's DNS to: $NPM_HOST:5354"
echo ""

echo -e "${YELLOW}Credentials:${NC}"
echo "  Nginx Proxy Manager: admin@example.com / changeme"
echo ""

echo -e "${YELLOW}Troubleshooting:${NC}"
echo "  • If SSL certificates fail to issue:"
echo "    - Ensure domains resolve to $NPM_HOST"
echo "    - Check that Nginx can reach letsencrypt.org"
echo "    - Verify Let's Encrypt email is correct"
echo ""
echo "  • To rerun setup:"
echo "    bash auto-setup-full.sh $NPM_HOST $NPM_PORT $DOMAIN $LE_EMAIL"
echo ""
