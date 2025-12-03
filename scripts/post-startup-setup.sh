#!/bin/bash
# Lara-Berry Post-Startup Setup (host-friendly)
# This script will:
#  - Attempt to bring up the stack using Podman Compose (if `docker-compose.yml` present)
#  - Resolve container IPs and wait for services
#  - Run the existing post-startup tasks (create proxy hosts, DNS zones, etc.)

set -euo pipefail

# Source .env file if it exists
if [ -f .env ]; then
    source .env
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration from environment variables or defaults
NPM_HOST="${NPM_HOST:-nginx-proxy-manager}"
NPM_PORT="${NPM_PORT:-81}"
# Base domain from DOMAIN env var
BASE_DOMAIN="${DOMAIN:-persephone}"
PI_IP="${PI_IP:-192.168.88.165}"
DNS_HOST="${DNS_HOST:-technitium-dns}"
DNS_PORT="${DNS_PORT:-5380}"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Lara-Berry Post-Startup Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Configuration:"
echo "  NPM Host: $NPM_HOST:$NPM_PORT"
echo "  Base Domain: $BASE_DOMAIN"
echo "  PI IP: $PI_IP"
echo "  DNS Host: $DNS_HOST:$DNS_PORT"
echo ""

# Helper: check command exists
have_cmd() { command -v "$1" >/dev/null 2>&1; }

# ============================================================================
# Podman / Compose orchestration (host)
# If a compose file exists, try to bring up the stack with Podman Compose.
# ============================================================================
bring_up_with_podman() {
    if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
        return 0
    fi

    if ! have_cmd podman; then
        echo -e "${YELLOW}Podman not found. Please install Podman on the host and re-run this script.${NC}"
        return 1
    fi

    # Prefer built-in `podman compose` if available, otherwise fall back to podman-compose
    if podman compose version >/dev/null 2>&1; then
        COMPOSE_CMD="podman compose"
    elif have_cmd podman-compose; then
        COMPOSE_CMD="podman-compose"
    else
        echo -e "${YELLOW}Neither 'podman compose' nor 'podman-compose' is available.${NC}"
        echo -e "${YELLOW}Install the Podman Compose plugin or the podman-compose package.${NC}"
        return 1
    fi

    echo -e "${BLUE}Bringing up the stack with: ${COMPOSE_CMD}${NC}"
    # Pull images (best-effort) and start services
    $COMPOSE_CMD pull || true
    $COMPOSE_CMD up -d

    return 0
}

# ============================================================================
# Helper: get a container's IP address by name using Podman
# ============================================================================
get_container_ip() {
    local name="$1"
    if ! have_cmd podman; then
        return 1
    fi
    # Look for a matching container
    cid=$(podman ps -a --filter "name=${name}" -q | head -n1 || true)
    if [ -z "${cid}" ]; then
        echo ""
        return 0
    fi
    # Try to read the container IP from network settings
    ip=$(podman inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${cid}" 2>/dev/null || true)
    echo "${ip}"
}

# ============================================================================
# Function: Retry with backoff
# ============================================================================
retry_with_backoff() {
    local max_attempts=10
    local timeout=2
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if eval "$@"; then
            return 0
        fi
        if [ $attempt -lt $max_attempts ]; then
            echo -e "${YELLOW}    Attempt $attempt/$max_attempts failed, waiting ${timeout}s...${NC}"
            sleep $timeout
            timeout=$((timeout < 16 ? timeout * 2 : 16))
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

# If running on a host with Podman and a compose file exists, try to bring up the stack
if [ "$(${SHELL:-/bin/sh} -c 'ps -o comm= -p $$' 2>/dev/null || true)" != "container-sh" ]; then
    # Best-effort: attempt to start podman compose stack before continuing
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        if bring_up_with_podman; then
            echo -e "${GREEN}Podman Compose stack started (or already running).${NC}"
        else
            echo -e "${YELLOW}Warning: Podman Compose step failed or was skipped. Continuing to post-startup steps.${NC}"
        fi
    fi
fi

# ============================================================================
# Function: Retry with backoff
# ============================================================================
retry_with_backoff() {
    local max_attempts=10
    local timeout=2
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$@"; then
            return 0
        fi
        if [ $attempt -lt $max_attempts ]; then
            echo -e "${YELLOW}    Attempt $attempt/$max_attempts failed, waiting ${timeout}s...${NC}"
            sleep $timeout
            timeout=$((timeout < 16 ? timeout * 2 : 16))
        fi
        attempt=$((attempt + 1))
    done
    
    return 1
}

# ============================================================================
# Step 1: Wait for services to be ready
# Uses container IPs when running on host
# ============================================================================
echo -e "${BLUE}Step 1: Waiting for services to start...${NC}"
echo ""

# Resolve hosts to IPs where possible (use podman inspect when available)
NPM_HOST_IP="$(get_container_ip "$NPM_HOST")"
DNS_HOST_IP="$(get_container_ip "$DNS_HOST")"
VAULTWARDEN_IP="$(get_container_ip "vaultwarden")"
UPTIME_IP="$(get_container_ip "uptime-kuma")"

try_curl() {
    local url="$1"
    if curl -s -f "$url" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

echo "  Waiting for Nginx Proxy Manager..."
if [ -n "$NPM_HOST_IP" ]; then
    TARGET="http://${NPM_HOST_IP}:${NPM_PORT}"
else
    TARGET="http://${NPM_HOST}:${NPM_PORT}"
fi
if retry_with_backoff "try_curl '$TARGET'"; then
    echo -e "${GREEN}  ✓ Nginx Proxy Manager ready (${TARGET})${NC}"
else
    echo -e "${RED}  ✗ Nginx Proxy Manager not responding (${TARGET})${NC}"
    exit 1
fi

echo "  Waiting for Technitium DNS..."
if [ -n "$DNS_HOST_IP" ]; then
    TARGET="http://${DNS_HOST_IP}:${DNS_PORT}"
else
    TARGET="http://${DNS_HOST}:${DNS_PORT}"
fi
if retry_with_backoff "try_curl '$TARGET'"; then
    echo -e "${GREEN}  ✓ Technitium DNS ready (${TARGET})${NC}"
else
    echo -e "${YELLOW}  ⚠ Technitium DNS not responding (non-critical) (${TARGET})${NC}"
fi

echo "  Waiting for Vaultwarden..."
if [ -n "$VAULTWARDEN_IP" ]; then
    TARGET="http://${VAULTWARDEN_IP}:80"
else
    TARGET="http://vaultwarden:80"
fi
if retry_with_backoff "try_curl '$TARGET'"; then
    echo -e "${GREEN}  ✓ Vaultwarden ready (${TARGET})${NC}"
else
    echo -e "${YELLOW}  ⚠ Vaultwarden not responding (non-critical) (${TARGET})${NC}"
fi

echo "  Waiting for Uptime Kuma..."
if [ -n "$UPTIME_IP" ]; then
    TARGET="http://${UPTIME_IP}:3001"
else
    TARGET="http://uptime-kuma:3001"
fi
if retry_with_backoff "try_curl '$TARGET'"; then
    echo -e "${GREEN}  ✓ Uptime Kuma ready (${TARGET})${NC}"
else
    echo -e "${YELLOW}  ⚠ Uptime Kuma not responding (non-critical) (${TARGET})${NC}"
fi

echo ""

# ============================================================================
# Step 2: Authenticate with Nginx Proxy Manager
# ============================================================================
echo -e "${BLUE}Step 2: Authenticating with Nginx Proxy Manager...${NC}"
echo ""

AUTH_TOKEN=""
# Try authentication with fewer retries
if retry_with_backoff "AUTH_RESPONSE=\$(curl -s --max-time 5 -X POST 'http://$NPM_HOST:$NPM_PORT/api/tokens' \
  -H 'Content-Type: application/json' \
  -d '{
    \"identity\": \"admin@example.com\",
    \"secret\": \"changeme\"
  }') && AUTH_TOKEN=\$(echo \"\$AUTH_RESPONSE\" | grep -o '\"token\":\"[^\"]*' | cut -d'\"' -f4) && [ -n \"\$AUTH_TOKEN\" ]"; then
    echo -e "${GREEN}✓ Authentication successful${NC}"
else
    echo -e "${YELLOW}⚠ Authentication failed - NPM may need manual setup${NC}"
    echo -e "${YELLOW}  This is normal if NPM credentials have been changed${NC}"
    AUTH_TOKEN=""
fi

echo ""

# ============================================================================
# Step 3: Create proxy hosts (only if authenticated)
# ============================================================================
if [ -n "$AUTH_TOKEN" ]; then
    echo -e "${BLUE}Step 3: Creating proxy hosts...${NC}"
    echo ""

    # Function to create proxy host
    create_proxy_host() {
        local subdomain=$1
        local forward_host=$2
        local forward_port=$3
        local websocket=${4:-false}
        
        echo "  Creating: ${subdomain}.${BASE_DOMAIN} → ${forward_host}:${forward_port}"
        
        RESPONSE=$(curl -s -X POST "http://$NPM_HOST:$NPM_PORT/api/nginx/proxy-hosts" \
          -H "Authorization: Bearer $AUTH_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{
            \"domain_names\": [\"${subdomain}.${BASE_DOMAIN}\"],
            \"forward_host\": \"${forward_host}\",
            \"forward_port\": ${forward_port},
            \"forward_scheme\": \"http\",
            \"block_exploits\": true,
            \"websocket_support\": ${websocket},
            \"caching_enabled\": false,
            \"access_list_id\": 0,
            \"certificate_id\": 0,
            \"ssl_forced\": false,
            \"http2_support\": true,
            \"hsts_enabled\": false,
            \"hsts_subdomains\": false
          }")
        
        if echo "$RESPONSE" | grep -q '"id"'; then
            echo -e "${GREEN}    ✓ ${subdomain}.${BASE_DOMAIN} created${NC}"
        else
            echo -e "${YELLOW}    ⚠ ${subdomain}.${BASE_DOMAIN} may already exist${NC}"
        fi
    }

    # Create proxy hosts for each service
    create_proxy_host "vaultwarden" "host.docker.internal" "8082" "true"
    create_proxy_host "uptime" "host.docker.internal" "3001" "true"
    create_proxy_host "dns" "host.docker.internal" "5381" "false"
    
    echo ""
else
    echo -e "${YELLOW}Step 3: Skipping proxy host creation (not authenticated)${NC}"
    echo -e "${YELLOW}  Services are running and accessible directly:${NC}"
    echo -e "${YELLOW}  • Vaultwarden: http://$PI_IP:8082${NC}"
    echo -e "${YELLOW}  • Uptime Kuma: http://$PI_IP:3001${NC}"
    echo -e "${YELLOW}  • Technitium: http://$PI_IP:5381${NC}"
    echo ""
fi

# ============================================================================
# Step 4: Setup DNS zones in Technitium (if available)
# ============================================================================
echo -e "${BLUE}Step 4: Setting up DNS zones...${NC}"
echo ""

if curl -s -f "http://$DNS_HOST:$DNS_PORT" > /dev/null 2>&1; then
    echo "  Creating DNS zone: $DOMAIN"
    
    # Create primary zone
    curl -s -X POST "http://$DNS_HOST:$DNS_PORT/api/zones/create" \
      -H "Content-Type: application/json" \
      -d "{\"name\": \"$DOMAIN\", \"type\": \"Primary\"}" > /dev/null 2>&1
    
    # Add A record for @ (root domain)
    curl -s -X POST "http://$DNS_HOST:$DNS_PORT/api/zones/records/add" \
      -H "Content-Type: application/json" \
      -d "{\"zone\": \"$DOMAIN\", \"domain\": \"$DOMAIN\", \"type\": \"A\", \"ipAddress\": \"$PI_IP\", \"ttl\": 3600}" > /dev/null 2>&1
    
    # Add A records for subdomains
    for subdomain in vaultwarden uptime dns; do
        curl -s -X POST "http://$DNS_HOST:$DNS_PORT/api/zones/records/add" \
          -H "Content-Type: application/json" \
          -d "{\"zone\": \"$DOMAIN\", \"domain\": \"${subdomain}.${DOMAIN}\", \"type\": \"A\", \"ipAddress\": \"$PI_IP\", \"ttl\": 3600}" > /dev/null 2>&1
    done
    
    echo -e "${GREEN}  ✓ DNS zones configured${NC}"
else
    echo -e "${YELLOW}  ⚠ Technitium DNS not available, skipping${NC}"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Services are accessible at:"
echo "  • Nginx Proxy Manager: http://$PI_IP:8081 (admin interface)"
echo "  • Nginx Proxy: http://$PI_IP:8080 or https://$PI_IP:8443 (proxied services)"
echo "  • Technitium DNS: http://$PI_IP:5381"
echo "  • Vaultwarden: http://$PI_IP:8082"
echo "  • Uptime Kuma: http://$PI_IP:3001"
echo ""
if [ -n "$AUTH_TOKEN" ]; then
    echo "Proxy hosts created:"
    echo "  • vaultwarden.$BASE_DOMAIN"
    echo "  • uptime.$BASE_DOMAIN"
    echo "  • dns.$BASE_DOMAIN"
    echo ""
fi
echo "Default NPM credentials:"
echo "  Email: admin@example.com"
echo "  Password: changeme"
echo "  (Change these immediately!)"
echo ""
echo -e "${YELLOW}Note: If using domain names, configure your DNS servers to use${NC}"
echo -e "${YELLOW}      Technitium DNS at $PI_IP:5354 (UDP/TCP)${NC}"
echo ""
